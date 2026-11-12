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

  factory FirebaseBackendConfig.fromEnvironment() =>
      const FirebaseBackendConfig(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        senderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
        webVapidKey: String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
      );
}
