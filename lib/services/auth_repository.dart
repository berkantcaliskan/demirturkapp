import 'package:supabase_flutter/supabase_flutter.dart';


/// Supabase Auth boundary used by the presentation layer.
/// Keeping the SDK here avoids coupling screens and state to Supabase types.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String phone,
    required String password,
  }) async {
    try {
      await _client.functions.invoke(
        'register-phone-account',
        body: {
          'phone': phone,
          'password': password,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw AuthException(
        message ?? 'Hesap açılamadı. Bilgilerinizi kontrol edip tekrar deneyin.',
      );
    }
    return signIn(phone: phone, password: password);
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
