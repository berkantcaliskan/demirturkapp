import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Moves the existing session only after its encrypted copy is safely written.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required String projectUrl,
    FlutterSecureStorage? secureStorage, LocalStorage? legacyStorage})
      : _key = 'sb-${Uri.parse(projectUrl).host.split('.').first}-auth-token',
        _secure = secureStorage ?? const FlutterSecureStorage(
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        ),
        _legacy = legacyStorage ?? SharedPreferencesLocalStorage(
          persistSessionKey: 'sb-${Uri.parse(projectUrl).host.split('.').first}-auth-token');

  final String _key;
  final FlutterSecureStorage _secure;
  final LocalStorage _legacy;

  @override
  Future<void> initialize() async {
    await _legacy.initialize();
    final encrypted = await _secure.read(key: _key);
    if (encrypted == null) {
      final previous = await _legacy.accessToken();
      if (previous != null) await _secure.write(key: _key, value: previous);
    }
    await _legacy.removePersistedSession();
  }

  @override
  Future<String?> accessToken() => _secure.read(key: _key);
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secure.write(key: _key, value: persistSessionString);
    await _legacy.removePersistedSession();
  }
  @override
  Future<void> removePersistedSession() async {
    await _secure.delete(key: _key);
    await _legacy.removePersistedSession();
  }
}
