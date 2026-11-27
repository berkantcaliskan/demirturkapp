import './user_facing_error.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await _initializeFirebaseApp();
  // FCM displays notification payloads while the app is in the background.
}

Future<void> _initializeFirebaseApp() async {
  final config = FirebaseBackendConfig.fromEnvironment();
  if (!config.isConfigured &&
      (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
    throw StateError('Firebase configuration is unavailable for this platform');
  }
  await Firebase.initializeApp(
    options: config.isConfigured
        ? FirebaseOptions(
            apiKey: config.apiKey,
            appId: config.appId,
            messagingSenderId: config.senderId,
            projectId: config.projectId,
            iosBundleId: config.iosBundleId.isEmpty ? null : config.iosBundleId,
          )
        : null,
  );
}

class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient _client;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _userId;
  bool _disposed = false;
  int _notificationId = 0;

  static bool get isConfigured => Firebase.apps.isNotEmpty;
  bool get _active => !_disposed && _userId == _client.auth.currentUser?.id;
  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<bool> initializeFirebase() async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS)
      return false;
    try {
      if (Firebase.apps.isEmpty) await _initializeFirebaseApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      return true;
    } catch (error) {
      debugPrint(userFacingError(error, fallback: 'FCM initialization failed. Tekrar deneyin.'));
      return false;
    }
  }

  Future<void> start({
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(Map<String, dynamic>) onOpened,
  }) async {
    _userId = _client.auth.currentUser?.id;
    if (_userId == null || !isConfigured || _disposed) return;
    try {
      if (_mobile) {
        await _local.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            if (!_active || response.payload == null) return;
            try {
              final payload =
                  jsonDecode(response.payload!) as Map<String, dynamic>;
              if (_forCurrentUser(payload)) onOpened(payload);
            } catch (error) {
              debugPrint(userFacingError(error, fallback: 'Invalid notification payload. Tekrar deneyin.'));
            }
          },
        );
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'demirturk_updates',
                'Demirtürk bildirimleri',
                description: 'Mesajlar, sözleşme ve ödeme bildirimleri',
                importance: Importance.high,
              ),
            );
      }
      if (!_active) return;
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) async {
        await _saveToken(token);
      });
      await _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        if (!_forCurrentUser(message.data)) return;
        onMessage(message.data);
        if (_mobile) unawaited(_showForeground(message));
      });
      await _openedSubscription?.cancel();
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        if (_forCurrentUser(message.data)) onOpened(message.data);
      });
      if (!kIsWeb) await enable();
      if (!_active) return;
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null && _forCurrentUser(initialMessage.data)) {
        onOpened(initialMessage.data);
      }
      if (_mobile) {
        final launch = await _local.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (launch?.didNotificationLaunchApp == true &&
            payload != null &&
            _active) {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          if (_forCurrentUser(data)) onOpened(data);
        }
      }
    } catch (error) {
      debugPrint(userFacingError(error, fallback: 'FCM device registration failed. Tekrar deneyin.'));
    }
  }

  bool _forCurrentUser(Map<String, dynamic> payload) =>
      _active &&
      (payload['recipient_user_id'] == null ||
          payload['recipient_user_id'] == _userId);

  Future<bool> enable() async {
    if (!isConfigured || !_active) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_active || settings.authorizationStatus == AuthorizationStatus.denied)
      return false;
    final config = FirebaseBackendConfig.fromEnvironment();
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb && config.webVapidKey.isNotEmpty
          ? config.webVapidKey
          : null,
    );
    if (token == null || !_active) return false;
    return await _saveToken(token) && _active;
  }

  Future<bool> _saveToken(String token) async {
    if (!_active) return false;
    try {
      await _client.rpc(
        'register_push_device',
        params: {
          'p_token': token,
          'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );
      return true;
    } catch (error) {
      debugPrint(userFacingError(error, fallback: 'FCM token registration failed. Tekrar deneyin.'));
      return false;
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (!_active || message.notification == null) return;
    try {
      await _local.show(
        id: _notificationId++,
        title: message.notification!.title,
        body: message.notification!.body,
        payload: jsonEncode(message.data),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'demirturk_updates',
            'Demirtürk bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint(userFacingError(error, fallback: 'Foreground notification failed. Tekrar deneyin.'));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }

  Future<void> unregisterCurrentToken() async {
    await dispose();
    if (!isConfigured) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _client.from('push_devices').delete().eq('token', token);
    }
    await FirebaseMessaging.instance.deleteToken();
    if (_mobile) await _local.cancelAll();
  }
}
