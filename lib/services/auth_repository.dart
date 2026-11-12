import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

/// Supabase Auth boundary used by the presentation layer.
/// Keeping the SDK here avoids coupling screens and state to Supabase types.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  /// Phone signup is allowed only when Supabase auto-confirms the phone.
  /// This public Auth setting check prevents a signup attempt from triggering
  /// a paid SMS while the project still requires an OTP.
  Future<bool> phoneSignupWithoutSmsIsEnabled() async {
    final config = BackendConfig.fromEnvironment();
    if (!config.isConfigured) return false;
    try {
      final response = await http
          .get(
            Uri.parse('${config.url}/auth/v1/settings'),
            headers: {'apikey': config.publishableKey!},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final settings = jsonDecode(response.body) as Map<String, dynamic>;
      final providers = settings['external'] as Map<String, dynamic>?;
      return providers?['phone'] == true &&
          settings['phone_autoconfirm'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResponse> register({
    required String phone,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      phone: phone,
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String phone,
    required String password,
  }) {
    return _client.auth.signInWithPassword(phone: phone, password: password);
  }

  Future<void> requestPasswordReset(String phone) =>
      _client.auth.signInWithOtp(phone: phone, shouldCreateUser: false);

  Future<AuthResponse> verifyPasswordResetCode({
    required String phone,
    required String token,
  }) => _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<void> requestPasswordChangeOtp() => _client.auth.reauthenticate();

  Future<UserResponse> updatePassword(String password, {String? nonce}) =>
      _client.auth.updateUser(UserAttributes(password: password, nonce: nonce));

  Future<void> verifyPhoneOtp({required String phone, required String token}) =>
      _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<void> resendPhoneOtp(String phone) =>
      _client.auth.resend(phone: phone, type: OtpType.sms);

  Future<void> signOut() => _client.auth.signOut();
}
