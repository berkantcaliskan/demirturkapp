import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/auth_repository.dart';
import '../../services/backend_config.dart';
import '../../utils/turkish_phone_input_formatter.dart';
import '../../widgets/website_blurred_background.dart';

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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isRegistering = false;
  bool _isAdmin = false;
  UserRole _selectedStaffRole = UserRole.management;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _awaitingOtp = false;
  bool _resetPasswordFlow = false;
  bool _resetPasswordReady = false;
  bool _passwordDotsLatched = false;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_handlePasswordFocusChange);
    _passwordController.addListener(_handlePasswordChange);
    _phoneController.addListener(_handlePhoneChange);
  }

  bool get _isPhoneReadyForPassword =>
      _normalizePhone(_phoneController.text) != null;

  bool get _showPasswordDotAnimation => _passwordDotsLatched;
  // SMS-based reset stays in the repository for a future verified release,
  // but is intentionally unavailable while SMS OTP is disabled in this MVP.
  bool get _canRequestPasswordReset => false;

  void _handlePhoneChange() {
    if (mounted) setState(() {});
  }

  void _handlePasswordChange() {
    if (mounted) setState(() {});
  }

  void _handlePasswordFocusChange() {
    if (!mounted) return;
    if (_passwordFocusNode.hasFocus && _isPhoneReadyForPassword) {
      _passwordDotsLatched = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    _passwordFocusNode
      ..removeListener(_handlePasswordFocusChange)
      ..dispose();
    _phoneController.removeListener(_handlePhoneChange);
    _passwordController.removeListener(_handlePasswordChange);
    super.dispose();
  }

  String? _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    // The UI accepts a Turkish national number: 10 digits without the trunk
    // zero, or 11 digits with it. Country code entry is intentionally omitted.
    if (digits.startsWith('0') && digits.length == 11) {
      return '+90${digits.substring(1)}';
    } else if (digits.length == 10) {
      return '+90$digits';
    }
    return null;
  }

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
    // Manager registration is handled by a trusted server function and never
    // enters the customer phone-OTP flow.
    if (_isAdmin && (_awaitingOtp || _resetPasswordFlow)) {
      setState(() {
        _awaitingOtp = false;
        _resetPasswordFlow = false;
        _resetPasswordReady = false;
        _otpController.clear();
      });
      _showMessage(
        'Yönetici hesapları uygulama içinden kaydedilmez. Mevcut yönetici hesabıyla giriş yapın.',
        isError: true,
      );
      return;
    }

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

    if (_isAdmin && _isRegistering) {
      _showMessage(
        'Personel kaydı yerel olarak açılamaz. Önce Supabase Auth hesabı oluşturup profiles tablosunda personel rolünü tanımlayın.',
        isError: true,
      );
      return;
    }

    final config = BackendConfig.fromEnvironment();
    if (!config.isConfigured) {
      _showMessage(
        'Giriş servisi henüz yapılandırılmadı. Supabase bağlantısı gerekiyor.',
        isError: true,
      );
      return;
    }

    final phone = _normalizePhone(_phoneController.text)!;
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
          _confirmController.clear();
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
            _passwordDotsLatched = false;
            _passwordController.clear();
            _confirmController.clear();
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
        );
        if (response.session == null || response.user == null) {
          _showMessage(
            'Hesap oturumu oluşturulamadı. Supabase Phone sağlayıcısında "Confirm phone" kapalı olmalı.',
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
        if (_isAdmin && !userRole.isStaff) {
          await auth.signOut();
          _showMessage(
            'Bu hesapta yönetici yetkisi bulunmuyor.',
            isError: true,
          );
          return;
        }
        if (!_isAdmin && userRole.isStaff) {
          await auth.signOut();
          _showMessage('Yönetici girişi bölümünü kullanın.', isError: true);
          return;
        }

        widget.onAuthenticated?.call(userRole);
      }
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } on PostgrestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('İşlem tamamlanamadı: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMode({bool? registering, bool? admin}) {
    setState(() {
      _isAdmin = admin ?? _isAdmin;
      _isRegistering = registering ?? _isRegistering;
      _awaitingOtp = false;
      _resetPasswordFlow = false;
      _resetPasswordReady = false;
      if ((admin ?? _isAdmin) && (registering ?? _isRegistering)) {
        _selectedStaffRole = UserRole.management;
      }
      _otpController.clear();
    });
  }

  Future<void> _requestPasswordReset() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone == null) {
      _showMessage('Önce geçerli telefon numaranızı girin.', isError: true);
      return;
    }
    final config = BackendConfig.fromEnvironment();
    if (!config.isConfigured) {
      _showMessage(
        'Parola sıfırlama için telefon doğrulama servisi gerekli.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthRepository(Supabase.instance.client)
          .requestPasswordReset(phone);
      setState(() {
        _awaitingOtp = true;
        _resetPasswordFlow = true;
        _resetPasswordReady = false;
        _otpController.clear();
      });
      _showMessage('Telefonunuza gelen kodu girin.');
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        'Kod gönderilemedi. Telefon numaranızı kontrol edip tekrar deneyin.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ManagerEntry(
              isDark: isDark,
              isAdmin: _isAdmin,
              onPressed: () => _setMode(admin: !_isAdmin, registering: false),
            ),
          ),
        ),
      ),
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
                                ? (_isAdmin
                                      ? 'Yönetici kaydı'
                                      : 'Hesap oluşturun')
                                : (_isAdmin
                                      ? 'Yönetici girişi'
                                      : 'Tekrar hoş geldiniz'),
                            key: ValueKey(
                              '$_isAdmin-$_isRegistering-$_awaitingOtp-title',
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
                                ? (_isAdmin
                                      ? 'Personel hesabı oluşturun.'
                                      : 'Demirtürk hesabınıza güvenle erişin.')
                                : 'Hesabınıza güvenli şekilde giriş yapın.',
                            key: ValueKey(
                              '$_isAdmin-$_isRegistering-$_awaitingOtp-subtitle',
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
                                if (_isRegistering &&
                                    !_awaitingOtp &&
                                    !_resetPasswordReady) ...[
                                  _AuthField(
                                    controller: _nameController,
                                    label: 'Ad soyad',
                                    hint: 'Adınızı ve soyadınızı girin',
                                    icon: CupertinoIcons.person,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    validator: (value) =>
                                        (value == null ||
                                            value.trim().length < 3)
                                        ? 'Ad soyad alanını doldurun.'
                                        : null,
                                  ),
                                  const SizedBox(height: 13),
                                ],
                                if (!_resetPasswordReady)
                                  _AuthField(
                                    controller: _phoneController,
                                    label: 'Telefon numarası',
                                    hint: '5XX XXX XX XX',
                                    icon: CupertinoIcons.phone,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    prefixText: '+90',
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      TurkishPhoneInputFormatter(),
                                    ],
                                    enabled: !_awaitingOtp,
                                    validator: (value) {
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
                                    label: 'Parola',
                                    hint: '6 haneli parolanız',
                                    icon: CupertinoIcons.lock,
                                    fill: fieldFill,
                                    foreground: foreground,
                                    muted: muted,
                                    focusNode: _passwordFocusNode,
                                    morphToDots: _showPasswordDotAnimation,
                                    dotCount: _passwordController.text.length,
                                    obscureText: !_isPasswordVisible,
                                    obscuringCharacter: '●',
                                    suffix:
                                        _canRequestPasswordReset &&
                                            !_showPasswordDotAnimation
                                        ? CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            onPressed: _requestPasswordReset,
                                            child: Text(
                                              'Unuttum',
                                              style: TextStyle(
                                                color: muted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        : IconButton(
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
                                    keyboardType:
                                        _isRegistering || _resetPasswordReady
                                        ? TextInputType.number
                                        : TextInputType.visiblePassword,
                                    inputFormatters:
                                        _isRegistering || _resetPasswordReady
                                        ? [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(6),
                                          ]
                                        : null,
                                    maxLength:
                                        _isRegistering || _resetPasswordReady
                                        ? 6
                                        : null,
                                    validator: (value) {
                                      if (_isRegistering ||
                                          _resetPasswordReady) {
                                        return value != null &&
                                                RegExp(r'^\d{6}$')
                                                    .hasMatch(value)
                                            ? null
                                            : 'Parola 6 rakamdan oluşmalı.';
                                      }
                                      return value == null || value.isEmpty
                                          ? 'Parola alanını doldurun.'
                                          : null;
                                    },
                                  ),
                                  if (_canRequestPasswordReset &&
                                      _showPasswordDotAnimation)
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
                                  if ((_isRegistering || _resetPasswordReady) &&
                                      !(_isAdmin && _isRegistering)) ...[
                                    const SizedBox(height: 13),
                                    _AuthField(
                                      controller: _confirmController,
                                      label: 'Parola tekrarı',
                                      hint: 'Parolanızı tekrar girin',
                                      icon: CupertinoIcons.lock_shield,
                                      fill: fieldFill,
                                      foreground: foreground,
                                      muted: muted,
                                      obscureText: true,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      maxLength: 6,
                                      validator: (value) =>
                                          value != _passwordController.text
                                          ? 'Parolalar eşleşmiyor.'
                                          : null,
                                    ),
                                  ],
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
                                if (_isAdmin &&
                                    _isRegistering &&
                                    !_awaitingOtp) ...[
                                  const SizedBox(height: 16),
                                  _buildStaffRoleSelector(
                                    foreground: foreground,
                                    muted: muted,
                                    isDark: isDark,
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

  Widget _buildStaffRoleSelector({
    required Color foreground,
    required Color muted,
    required bool isDark,
  }) {
    const options = <(UserRole, String)>[
      (UserRole.salesAdvisor, 'Satış Danışmanı'),
      (UserRole.accounting, 'Muhasebe'),
      (UserRole.management, 'Yönetim'),
    ];
    final selectedDescription = _selectedStaffRole.isSalesAdvisor
        ? 'Kendi müşterileri ve genel mesajlar'
        : 'Tüm müşteriler, mesajlar, senetler ve süreçler';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            'Hesap türü',
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: .055)
                : const Color(0xFF0F172A).withValues(alpha: .045),
            border: Border.all(color: AppGlass.dividerColor(context)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: options.map((option) {
              final selected = _selectedStaffRole == option.$1;
              return Expanded(
                child: CupertinoButton(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () =>
                      setState(() => _selectedStaffRole = option.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 42,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark ? const Color(0xFFF5F3F0) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      option.$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: selected ? foreground : muted,
                        fontSize: 10.5,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            selectedDescription,
            style: TextStyle(color: muted, fontSize: 10.5),
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
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.fill,
    required this.foreground,
    required this.muted,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.obscureText = false,
    this.prefixText,
    this.suffix,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.obscuringCharacter = '•',
    this.morphToDots = false,
    this.dotCount = 0,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color fill;
  final Color foreground;
  final Color muted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscureText;
  final String? prefixText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final String obscuringCharacter;
  final bool morphToDots;
  final int dotCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 880),
              curve: Curves.easeInOutCubic,
              width: morphToDots ? 142 : constraints.maxWidth,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(morphToDots ? 28 : 18),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeInOutCubic,
                    opacity: morphToDots ? 0 : 1,
                    child: TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: keyboardType,
                      inputFormatters: inputFormatters,
                      maxLength: maxLength,
                      obscureText: obscureText,
                      obscuringCharacter: obscuringCharacter,
                      enabled: enabled,
                      validator: validator,
                      style: TextStyle(
                        color: foreground,
                        fontSize: obscureText ? 19 : 13.5,
                        letterSpacing: obscureText ? 4 : 0,
                      ),
                      cursorColor: const Color(0xFFE11D48),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: muted.withValues(alpha: 0.82),
                          fontSize: 12.5,
                          letterSpacing: 0,
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
                          borderSide: BorderSide(
                            color: AppGlass.dividerColor(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1.1,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFE11D48),
                            width: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (morphToDots)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Semantics(
                          label: 'Parola alanı, $dotCount rakam girildi',
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                6,
                                (index) => _FlightPasswordDot(
                                  key: ValueKey('password-dot-$index'),
                                  color: index < dotCount
                                      ? const Color(0xFFE11D48)
                                      : muted.withValues(alpha: 0.74),
                                  filled: index < dotCount,
                                  index: index,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlightPasswordDot extends StatefulWidget {
  const _FlightPasswordDot({
    super.key,
    required this.color,
    required this.filled,
    required this.index,
  });

  final Color color;
  final bool filled;
  final int index;

  @override
  State<_FlightPasswordDot> createState() => _FlightPasswordDotState();
}

class _FlightPasswordDotState extends State<_FlightPasswordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final begin = widget.index * 0.08;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: Curves.easeOutCubic),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value;
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 22),
              child: Transform.rotate(
                angle: (1 - progress) * -0.35,
                child: Transform.scale(
                  scale: 0.4 + (progress * 0.6),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.filled ? widget.color : Colors.transparent,
            border: Border.all(color: widget.color, width: 1.6),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.20),
                      blurRadius: 7,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
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

class _ManagerEntry extends StatelessWidget {
  const _ManagerEntry({
    required this.isDark,
    required this.isAdmin,
    required this.onPressed,
  });

  final bool isDark;
  final bool isAdmin;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin
        ? const Color(0xFFE11D48)
        : AppGlass.textMuted(context);
    return Center(
      child: Semantics(
        button: true,
        label: isAdmin ? 'Müşteri girişi' : 'Yönetici girişi',
        child: Tooltip(
          message: isAdmin ? 'Müşteri girişi' : 'Yönetici girişi',
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(24),
            onPressed: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdmin
                    ? const Color(0xFFE11D48)
                          .withValues(alpha: isDark ? 0.17 : 0.10)
                    : Colors.transparent,
                border: Border.all(
                  color: isAdmin
                      ? const Color(0xFFE11D48).withValues(alpha: 0.54)
                      : AppGlass.dividerColor(context),
                ),
              ),
              child: Icon(
                CupertinoIcons.checkmark_shield_fill,
                size: 21,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

