import 'package:flutter/foundation.dart';

/// Build-time configuration for the hosted backend.
///
/// The publishable key is expected to be present in the client application;
/// authorization is enforced by Supabase Auth and database RLS policies.
class BackendConfig {
  const BackendConfig({required this.url, required this.publishableKey});

  final String? url;
  final String? publishableKey;

  bool get isConfigured =>
      url != null &&
      url!.isNotEmpty &&
      publishableKey != null &&
      publishableKey!.isNotEmpty;

  factory BackendConfig.fromEnvironment() => const BackendConfig(
    // These are public client credentials. RLS is the authorization boundary;
    // never put a service-role or secret API key in the Flutter application.
    url: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://twxkpypwagchnymeplxn.supabase.co',
    ),
    publishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_nRXoK1hCwPPApUDjehV9og_pv30psJ_',
    ),
  );
}

/// Firebase values are supplied by FlutterFire at build time. These values are
/// public client identifiers; service-account credentials remain server-side.
class FirebaseBackendConfig {
  const FirebaseBackendConfig({
    required this.apiKey,
    required this.appId,
    required this.senderId,
    required this.projectId,
    required this.iosBundleId,
    required this.webVapidKey,
  });

  final String apiKey;
  final String appId;
  final String senderId;
  final String projectId;
  final String iosBundleId;
  final String webVapidKey;

  bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty;

  factory FirebaseBackendConfig.fromEnvironment() {
    var appId = const String.fromEnvironment('FIREBASE_APP_ID');
    if (appId.isEmpty) {
      appId = kIsWeb
          ? '1:833952865318:web:7c0e25f433f20b2f715ae7'
          : defaultTargetPlatform == TargetPlatform.android
          ? '1:833952865318:android:ba089ccca4bf1b14715ae7'
          : '';
    }
    return FirebaseBackendConfig(
      apiKey: const String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: 'AIzaSyA_fNZAB0fGLFV9Arbk4iEklgB85NFOlEk',
      ),
      appId: appId,
      senderId: const String.fromEnvironment(
        'FIREBASE_SENDER_ID',
        defaultValue: '833952865318',
      ),
      projectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: 'demirturk-mobil-4954e',
      ),
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      webVapidKey: const String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
    );
  }
}
