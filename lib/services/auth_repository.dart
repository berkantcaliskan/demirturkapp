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
    required String fullName,
    required String email,
  }) async {
    try {
      await _client.functions.invoke(
        'register-phone-account',
        body: {
          'phone': phone,
          'password': password,
          'fullName': fullName,
          'email': email,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw AuthException(
        message ??
            'Hesap açılamadı. Bilgilerinizi kontrol edip tekrar deneyin.',
      );
    }
    return signIn(phone: phone, password: password);
  }

  Future<AuthResponse> signIn({
    required String phone,
    required String password,
  }) {
    return phone.contains('@')
        ? _client.auth.signInWithPassword(
            email: phone.trim().toLowerCase(),
            password: password,
          )
        : _client.auth.signInWithPassword(phone: phone, password: password);
  }

  Future<void> requestPasswordReset(String phone) =>
      _client.auth.signInWithOtp(phone: phone, shouldCreateUser: false);

  Future<AuthResponse> verifyPasswordResetCode({
    required String phone,
    required String token,
  }) => _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<void> requestPasswordChangeOtp() => _client.auth.reauthenticate();

  Future<void> verifyCurrentPassword(String password) async {
    final email = currentUser?.email;
    final identity = email != null && email.isNotEmpty
        ? email
        : currentUser?.phone;
    if (identity == null || identity.isEmpty)
      throw const AuthException(
        'Hesap bilgilerinizi doğrulamak için şirketle iletişime geçin.',
      );
    await signIn(phone: identity, password: password);
  }

  Future<Map<String, dynamic>> accountAction(
    String action, {
    Map<String, dynamic> values = const {},
  }) async {
    try {
      final result = await _client.functions.invoke(
        'account-settings',
        body: {'action': action, ...values},
      );
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (error) {
      throw AuthException(
        error.details is Map
            ? error.details['error']?.toString() ?? 'İşlem tamamlanamadı.'
            : 'İşlem tamamlanamadı.',
      );
    }
  }

  Future<UserResponse> updatePassword(String password, {String? nonce}) =>
      _client.auth.updateUser(UserAttributes(password: password, nonce: nonce));

  Future<void> verifyPhoneOtp({required String phone, required String token}) =>
      _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<void> resendPhoneOtp(String phone) =>
      _client.auth.resend(phone: phone, type: OtpType.sms);

  Future<void> signOut() => _client.auth.signOut();
}
