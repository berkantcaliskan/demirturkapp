import '../../services/user_facing_error.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/auth_repository.dart';
import '../../services/backend_config.dart';
import '../../services/staff_login_policy.dart';
import '../../utils/turkish_phone_input_formatter.dart';
import '../../widgets/website_blurred_background.dart';
import '../../widgets/company_links.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.appState, this.onAuthenticated});

  final AppState appState;
  final ValueChanged<UserRole>? onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const bool _demoLoginEnabled = bool.fromEnvironment(
    'ENABLE_DEMO_LOGIN',
  );
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _awaitingOtp = false;
  bool _resetPasswordFlow = false;
  bool _resetPasswordReady = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handlePasswordChange);
    _phoneController.addListener(_handlePhoneChange);
  }

  bool get _flexiblePassword =>
      !_isRegistering &&
      (_phoneController.text.contains('@') ||
          usesStaffPasswordInput(_phoneController.text));
  // Recover through the company after an independent identity check.
  bool get _canRequestPasswordReset => true;

  void _handlePhoneChange() {
    if (mounted) setState(() {});
  }

  void _handlePasswordChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handlePhoneChange);
    _passwordController.removeListener(_handlePasswordChange);
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _normalizePhone(String value) => normalizeTurkishPhoneNumber(value);

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFE11D48) : null,
          content: Text(message),
        ),
      );
  }

  Future<void> _submit() async {
    // Explicitly enabled only for local/review APKs. This session has no
    // Supabase identity and therefore cannot read or mutate production data.
    final enteredDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (_demoLoginEnabled &&
        !_isRegistering &&
        enteredDigits == '1111' &&
        _passwordController.text == '1111') {
      widget.onAuthenticated?.call(UserRole.management);
      widget.appState.setLocalStaffName('Deneme Yöneticisi');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final config = BackendConfig.fromEnvironment();
    if (!config.isConfigured) {
      _showMessage(
        'Giriş servisi henüz yapılandırılmadı. Supabase bağlantısı gerekiyor.',
        isError: true,
      );
      return;
    }

    final phone = _phoneController.text.contains('@')
        ? _phoneController.text.trim().toLowerCase()
        : _normalizePhone(_phoneController.text)!;
    setState(() => _isLoading = true);
    try {
      final auth = AuthRepository(Supabase.instance.client);
      if (_resetPasswordReady) {
        await auth.updatePassword(_passwordController.text);
        await auth.signOut();
        setState(() {
          _resetPasswordReady = false;
          _resetPasswordFlow = false;
          _passwordController.clear();
          _otpController.clear();
        });
        _showMessage(
          'Parolanız güncellendi. Yeni parolanızla giriş yapabilirsiniz.',
        );
        return;
      }
      if (_awaitingOtp) {
        if (_resetPasswordFlow) {
          await auth.verifyPasswordResetCode(
            phone: phone,
            token: _otpController.text.trim(),
          );
          setState(() {
            _awaitingOtp = false;
            _resetPasswordReady = true;
            _passwordController.clear();
          });
          _showMessage('Kod doğrulandı. Yeni parolanızı belirleyin.');
        } else {
          await auth.verifyPhoneOtp(
            phone: phone,
            token: _otpController.text.trim(),
          );
          setState(() => _awaitingOtp = false);
          _showMessage(
            'Telefon numaranız doğrulandı. Şimdi giriş yapabilirsiniz.',
          );
        }
      } else if (_isRegistering) {
        final response = await auth.register(
          phone: phone,
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
        );
        if (response.session == null || response.user == null) {
          _showMessage(
            'Hesap oluşturulamadı. Lütfen tekrar deneyin.',
            isError: true,
          );
          return;
        }
        widget.onAuthenticated?.call(UserRole.customer);
      } else {
        final response = await auth.signIn(
          phone: phone,
          password: _passwordController.text,
        );
        if (response.user == null) {
          _showMessage(
            'Oturum açılamadı. Bilgilerinizi kontrol edin.',
            isError: true,
          );
          return;
        }

        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role, staff_role')
            .eq('id', response.user!.id)
            .maybeSingle();
        final dbRole = profile?['role'] as String?;
        final staffRole = profile?['staff_role'] as String?;
        final userRole = switch (staffRole) {
          'sales_advisor' => UserRole.salesAdvisor,
          'accounting' => UserRole.accounting,
          'management' => UserRole.management,
          _ when dbRole == 'admin' => UserRole.admin,
          _ when dbRole == 'customer' => UserRole.customer,
          _ => null,
        };
        if (userRole == null) {
          await auth.signOut();
          _showMessage('Hesap profili bulunamadı.', isError: true);
          return;
        }
        widget.onAuthenticated?.call(userRole);
      }
    } on AuthException catch (error) {
      _showMessage(userFacingError(error), isError: true);
    } on PostgrestException catch (error) {
      _showMessage(userFacingError(error), isError: true);
    } catch (_) {
      _showMessage(
        _isRegistering
            ? 'Hesap oluşturulamadı. Kayıt servisi kullanılamıyor; lütfen daha sonra tekrar deneyin.'
            : 'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMode({bool? registering}) {
    _passwordController.clear();
    setState(() {
      _isRegistering = registering ?? _isRegistering;
      _awaitingOtp = false;
      _resetPasswordFlow = false;
      _resetPasswordReady = false;
      _otpController.clear();
    });
  }

  Future<void> _requestPasswordReset() async {
    final contact = await showDialog<CompanyLink>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabınızı kurtarın'),
        content: const Text(
          'Parolanızı unuttuysanız şirketimizle iletişime geçin. Kimliğiniz kontrol edildikten sonra hesabınızı kurtarmanıza yardımcı olacağız. Parolanızı veya doğrulama kodunuzu paylaşmayın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, companyEmail),
            child: const Text('E-posta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, companyPhone),
            child: const Text('Şirketi ara'),
          ),
        ],
      ),
    );
    if (contact != null && mounted) await openCompanyLink(context, contact);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final foreground = AppGlass.textPrimary(context);
    final secondary = AppGlass.textSecondary(context);
    final muted = AppGlass.textMuted(context);
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : const Color(0xFF0F172A).withValues(alpha: 0.035);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final contentMinHeight = (availableHeight - 42)
                .clamp(0.0, double.infinity)
                .toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: contentMinHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBrand(isDark, foreground, secondary),
                        const SizedBox(height: 34),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 430),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.10),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            _resetPasswordReady
                                ? 'Yeni parolanızı belirleyin'
                                : _awaitingOtp
                                ? 'Telefonunuzu doğrulayın'
                                : _isRegistering
                                ? 'Hesap oluşturun'
                                : 'Tekrar hoş geldiniz',
                            key: ValueKey(
                              '$_isRegistering-$_awaitingOtp-title',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 25,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.08),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            _resetPasswordReady
                                ? 'Yeni 6 haneli parolanızı oluşturun.'
                                : _awaitingOtp
                                ? _resetPasswordFlow
                                      ? 'SMS ile gelen 6 haneli kodu girin.'
                                      : 'SMS ile gelen 6 haneli kodu girin.'
                                : _isRegistering
                                ? 'Demirtürk hesabınıza güvenle erişin.'
                                : 'Hesabınıza güvenli şekilde giriş yapın.',
                            key: ValueKey(
                              '$_isRegistering-$_awaitingOtp-subtitle',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 27),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isRegistering) ...[
                                  _AuthField(
                                    controller: _nameController,
                                    label: 'Adı ve Soyadı',
                                    hint: 'Adınız ve soyadınız',
                                    icon: CupertinoIcons.person,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    validator: (value) =>
                                        (value?.trim().length ?? 0) >= 3
                                        ? null
                                        : 'Adınızı ve soyadınızı girin.',
                                  ),
                                  const SizedBox(height: 13),
                                  _AuthField(
                                    controller: _emailController,
                                    label: 'E-posta',
                                    hint: 'E-posta adresiniz',
                                    icon: CupertinoIcons.mail,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) =>
                                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(value?.trim() ?? '')
                                        ? null
                                        : 'Geçerli bir e-posta adresi girin.',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 5,
                                      bottom: 13,
                                    ),
                                    child: Text(
                                      'E-posta adresi kayıttan sonra değiştirilemez.',
                                      style: TextStyle(
                                        color: secondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                                if (!_resetPasswordReady)
                                  _AuthField(
                                    controller: _phoneController,
                                    label: _isRegistering
                                        ? 'Telefon numarası'
                                        : 'Telefon numarası veya e-posta',
                                    hint: _isRegistering
                                        ? '5XX XXX XX XX'
                                        : 'Telefon numaranız veya e-postanız',
                                    icon: CupertinoIcons.phone,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    prefixText: _isRegistering ? '+90' : null,
                                    keyboardType: _isRegistering
                                        ? TextInputType.phone
                                        : TextInputType.emailAddress,
                                    inputFormatters: [
                                      if (_isRegistering)
                                        TurkishPhoneInputFormatter(),
                                    ],
                                    enabled: !_awaitingOtp,
                                    validator: (value) {
                                      if (!_isRegistering &&
                                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                              .hasMatch(value?.trim() ?? ''))
                                        return null;
                                      return _normalizePhone(value ?? '') !=
                                              null
                                          ? null
                                          : 'Geçerli bir Türkiye telefon numarası girin.';
                                    },
                                  ),
                                if (!_awaitingOtp || _resetPasswordReady) ...[
                                  const SizedBox(height: 13),
                                  _AuthField(
                                    controller: _passwordController,
                                    key: ValueKey(
                                      'password-$_flexiblePassword-$_isRegistering',
                                    ),
                                    label: 'Şifre',
                                    hint: 'Şifreniz',
                                    icon: CupertinoIcons.lock,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    focusNode: _passwordFocusNode,
                                    obscureText: !_isPasswordVisible,
                                    obscuringCharacter: '●',
                                    suffix: IconButton(
                                      splashRadius: 18,
                                      onPressed: () => setState(
                                        () => _isPasswordVisible =
                                            !_isPasswordVisible,
                                      ),
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? CupertinoIcons.eye_slash
                                            : CupertinoIcons.eye,
                                        size: 18,
                                        color: muted,
                                      ),
                                    ),
                                    enabled: !_awaitingOtp,
                                    keyboardType: _flexiblePassword
                                        ? TextInputType.visiblePassword
                                        : TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      if (!_flexiblePassword)
                                        FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        _flexiblePassword ? 128 : 6,
                                      ),
                                    ],
                                    maxLength: _flexiblePassword ? 128 : 6,
                                    validator: (value) {
                                      if (_flexiblePassword) {
                                        return value != null &&
                                                value.length >= 6 &&
                                                value.length <= 128
                                            ? null
                                            : 'Parolanızı kontrol edin.';
                                      }
                                      if (_isRegistering ||
                                          _resetPasswordReady) {
                                        return value != null &&
                                                RegExp(r'^\d{6}$')
                                                    .hasMatch(value)
                                            ? null
                                            : 'Parola 6 rakamdan oluşmalı.';
                                      }
                                      return value != null &&
                                              RegExp(r'^\d{6}$').hasMatch(value)
                                          ? null
                                          : 'Parola 6 rakamdan oluşmalı.';
                                    },
                                  ),
                                  if (_canRequestPasswordReset)
                                    Align(
                                      alignment: Alignment.center,
                                      child: CupertinoButton(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        minimumSize: Size.zero,
                                        onPressed: _requestPasswordReset,
                                        child: Text(
                                          'Parolamı unuttum',
                                          style: TextStyle(
                                            color: secondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ] else if (_awaitingOtp) ...[
                                  const SizedBox(height: 13),
                                  _AuthField(
                                    controller: _otpController,
                                    label: 'Doğrulama kodu',
                                    hint: '6 haneli SMS kodu',
                                    icon: CupertinoIcons.number,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    keyboardType: TextInputType.number,
                                    validator: (value) =>
                                        (value == null ||
                                            value.trim().length != 6)
                                        ? '6 haneli kodu girin.'
                                        : null,
                                  ),
                                ],
                                const SizedBox(height: 19),
                                Center(
                                  child: SizedBox(
                                    width: 262,
                                    child: _PrimaryPillButton(
                                      isDark: isDark,
                                      isLoading: _isLoading,
                                      label: _resetPasswordReady
                                          ? 'Parolayı güncelle'
                                          : _awaitingOtp
                                          ? 'Kodu doğrula'
                                          : _isRegistering
                                          ? 'Kaydol'
                                          : 'Giriş yap',
                                      onPressed: _isLoading ? null : _submit,
                                    ),
                                  ),
                                ),
                                if (_awaitingOtp) ...[
                                  const SizedBox(height: 10),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    onPressed: _isLoading ? null : _resendOtp,
                                    child: Text(
                                      'Kodu tekrar gönder',
                                      style: TextStyle(color: secondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 27),
                        Center(
                          child: SizedBox(
                            width: 88,
                            child: _ModeToggle(
                              isDark: isDark,
                              isRegistering: _isRegistering,
                              onChange: _awaitingOtp
                                  ? null
                                  : (registering) =>
                                        _setMode(registering: registering),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const CompanyLinksFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrand(bool isDark, Color foreground, Color secondary) {
    return Column(
      children: [
        Image.asset(
          isDark
              ? 'assets/images/demirturk-emblem-white.png'
              : 'assets/images/demirturk-emblem-dark.png',
          width: 62,
          height: 48,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Text(
          'DEMİRTÜRK',
          style: TextStyle(
            color: foreground,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'M O B İ L',
          style: TextStyle(
            color: secondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Future<void> _resendOtp() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone == null) return;
    setState(() => _isLoading = true);
    try {
      final auth = AuthRepository(Supabase.instance.client);
      if (_resetPasswordFlow) {
        await auth.requestPasswordReset(phone);
      } else {
        await auth.resendPhoneOtp(phone);
      }
      _showMessage('Yeni doğrulama kodu gönderildi.');
    } on AuthException catch (error) {
      _showMessage(userFacingError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.fill,
    required this.foreground,
    required this.muted,
    this.focusNode,
    this.prefixText,
    this.suffix,
    this.obscureText = false,
    this.obscuringCharacter = '●',
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.validator,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final Color fill, foreground, muted;
  final FocusNode? focusNode;
  final String? prefixText;
  final Widget? suffix;
  final bool obscureText, enabled;
  final String obscuringCharacter;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 7),
      ],
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        obscureText: obscureText,
        obscuringCharacter: obscuringCharacter,
        autocorrect: false,
        enableSuggestions: false,
        enabled: enabled,
        validator: validator,
        style: TextStyle(color: foreground, fontSize: 13.5),
        cursorColor: const Color(0xFFE11D48),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: muted.withValues(alpha: .82),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(icon, size: 18, color: muted),
          prefixText: prefixText,
          prefixStyle: TextStyle(
            color: foreground,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          suffixIcon: suffix,
          filled: true,
          counterText: '',
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppGlass.dividerColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE11D48)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.1),
          ),
        ),
      ),
    ],
  );
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.isDark,
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? const Color(0xFFF5F3F0)
        : const Color(0xFF1E293B);
    final foreground = isDark ? const Color(0xFF171513) : Colors.white;
    return SizedBox(
      height: 52,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(28),
        color: background,
        disabledColor: background.withValues(alpha: 0.58),
        onPressed: onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.arrow_right, size: 16, color: foreground),
                ],
              ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.isDark,
    required this.isRegistering,
    required this.onChange,
  });

  final bool isDark;
  final bool isRegistering;
  final ValueChanged<bool>? onChange;

  @override
  Widget build(BuildContext context) {
    final foreground = AppGlass.textPrimary(context);
    final muted = AppGlass.textMuted(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : const Color(0xFF0F172A).withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppGlass.dividerColor(context)),
      ),
      child: Row(
        children: [
          _ToggleOption(
            selected: !isRegistering,
            icon: CupertinoIcons.person_crop_circle,
            semanticLabel: 'Giriş yap',
            foreground: foreground,
            muted: muted,
            onTap: onChange == null ? null : () => onChange!(false),
          ),
          _ToggleOption(
            selected: isRegistering,
            icon: CupertinoIcons.person_badge_plus,
            semanticLabel: 'Kaydol',
            foreground: foreground,
            muted: muted,
            onTap: onChange == null ? null : () => onChange!(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.selected,
    required this.icon,
    required this.semanticLabel,
    required this.foreground,
    required this.muted,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String semanticLabel;
  final Color foreground;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel,
        selected: selected,
        child: Tooltip(
          message: semanticLabel,
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(24),
            color: Colors.transparent,
            onPressed: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 17, color: selected ? foreground : muted),
            ),
          ),
        ),
      ),
    );
  }
}
