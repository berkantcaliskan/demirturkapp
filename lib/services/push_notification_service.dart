import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final config = FirebaseBackendConfig.fromEnvironment();
  if (config.isConfigured && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: _optionsFor(config));
  }
  // The operating system renders notification payloads while the app is away.
  // Data-only messages are intentionally not presented as system notifications.
}

FirebaseOptions _optionsFor(FirebaseBackendConfig config) => FirebaseOptions(
  apiKey: config.apiKey,
  appId: config.appId,
  messagingSenderId: config.senderId,
  projectId: config.projectId,
  iosBundleId: config.iosBundleId.isEmpty ? null : config.iosBundleId,
);

/// Registers the current device against its authenticated Supabase user and
/// refreshes that registration whenever FCM rotates its token.
class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient _client;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  static Future<bool> initializeFirebase() async {
    final config = FirebaseBackendConfig.fromEnvironment();
    if (!config.isConfigured) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _optionsFor(config));
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      return true;
    } catch (error, stack) {
      debugPrint('FCM initialization failed: $error\n$stack');
      return false;
    }
  }

  Future<void> start({
    required void Function(Map<String, dynamic> payload) onMessage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final config = FirebaseBackendConfig.fromEnvironment();
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb && config.webVapidKey.isNotEmpty
            ? config.webVapidKey
            : null,
      );
      if (token != null) await _saveToken(token);
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) => unawaited(_saveToken(newToken)),
      );
      await _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        onMessage(message.data);
      });
      await _openedSubscription?.cancel();
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        onMessage(message.data);
      });
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) onMessage(initialMessage.data);
    } catch (error, stack) {
      debugPrint('FCM device registration failed: $error\n$stack');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('push_devices').upsert({
      'user_id': user.id,
      'token': token,
      'platform': _platformName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<void> unregisterCurrentToken() async {
    if (Firebase.apps.isEmpty) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _client.from('push_devices').delete().eq('token', token);
    }
    await FirebaseMessaging.instance.deleteToken();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
