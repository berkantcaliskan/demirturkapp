import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_state.dart';
import '../../services/auth_repository.dart';
import '../../services/account_pdf_export.dart';
import '../../services/portal_repository.dart';
import '../../utils/turkish_phone_input_formatter.dart';
import '../../widgets/company_links.dart';
import '../../widgets/website_blurred_background.dart';
import 'customer_contract_card.dart';

class CustomerAccountSettings extends StatefulWidget {
  const CustomerAccountSettings({
    super.key,
    required this.state,
    required this.repository,
    required this.onLogout,
    required this.onUpdated,
    required this.onThemeChanged,
    required this.onNotifications,
  });
  final AppState state;
  final PortalRepository? repository;
  final VoidCallback onLogout;
  final Future<void> Function() onUpdated;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onNotifications;
  @override
  State<CustomerAccountSettings> createState() =>
      _CustomerAccountSettingsState();
}

class _CustomerAccountSettingsState extends State<CustomerAccountSettings> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController();
  Map<String, dynamic> _account = {};
  bool _busy = false, _loaded = false;
  String? _error;
  AuthRepository get _auth => AuthRepository(Supabase.instance.client);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.repository == null) {
      setState(() => _error = 'Hesap ayarları için oturum açın.');
      return;
    }
    try {
      final a = await _auth.accountAction('read');
      if (!mounted) return;
      setState(() {
        _account = a;
        _name.text = a['name'] ?? '';
        _email.text = a['email'] ?? '';
        _phone.text = a['phone'] ?? '';
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Hesap bilgileri yüklenemedi.',
        );
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _message(
        e is AuthException ? e.message : 'İşlem tamamlanamadı. Tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassword(String title) async {
    final password = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: password,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Mevcut parola'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, password.text),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    password.dispose();
    return result;
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 3 ||
        normalizeTurkishPhoneNumber(_phone.text) == null) {
      _message('Ad soyad ve telefon numarasını kontrol edin.');
      return;
    }
    if ((_account['email'] ?? '').isEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      _message('Geçerli bir e-posta girin.');
      return;
    }
    final password = await _askPassword('Bilgileri kaydet');
    if (password == null || password.isEmpty) return;
    await _run(() async {
      await _auth.accountAction(
        'update',
        values: {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text,
          'currentPassword': password,
        },
      );
      await Supabase.instance.client.auth.refreshSession();
      await _load();
      await widget.onUpdated();
      _message('Hesap bilgileriniz güncellendi.');
    });
  }

  Future<void> _password() async {
    final current = TextEditingController(),
        next = TextEditingController(),
        confirm = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şifreyi değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              (current, 'Mevcut parola'),
              (next, 'Yeni parola'),
              (confirm, 'Yeni parola tekrarı'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: item.$1,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(labelText: item.$2),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, [current.text, next.text, confirm.text]),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (result == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(result[1]) || result[1] != result[2]) {
      _message('Yeni parolalar aynı ve 6 rakamdan oluşmalı.');
      return;
    }
    await _run(() async {
      await _auth.accountAction(
        'password',
        values: {'currentPassword': result[0], 'password': result[1]},
      );
      _message('Parolanız güncellendi.');
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı sil'),
        content: const Text(
          'Hesabınız ve giriş erişiminiz kalıcı olarak silinir. Sözleşme, ödeme ve yazışma kayıtları şirketin yasal yükümlülükleri ve güvenlik incelemeleri kapsamında yalnızca yetkili personelin erişiminde saklanabilir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hesabımı sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = await _askPassword('Silme işlemini doğrula');
    if (password == null || password.isEmpty) return;
    await _run(() async {
      await _auth.accountAction(
        'delete',
        values: {'currentPassword': password},
      );
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      widget.state.clearSessionData();
      widget.onLogout();
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
    children: [
      Text(
        'Hesap ayarları',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppGlass.textPrimary(context),
        ),
      ),
      const SizedBox(height: 16),
      if (_error != null) ...[
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Tekrar dene')),
      ],
      if (!_loaded && _error == null)
        const Center(child: CircularProgressIndicator()),
      if (_loaded) ...[
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Adı ve Soyadı'),
                maxLength: 100,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                readOnly: (_account['email'] ?? '').isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  helperText:
                      'E-posta adresi kaydedildikten sonra değiştirilemez.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [TurkishPhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefon numarası',
                ),
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Bilgileri kaydet'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Hesap verilerini indir'),
                subtitle: const Text(
                  'Size ait satın alım, sözleşme ve ödeme bilgileri · PDF',
                ),
                onTap: _busy
                    ? null
                    : () => _run(() async {
                        await widget.onUpdated();
                        final account = await _auth.accountAction('read');
                        await shareAccountPdf(widget.state, account);
                      }),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Şifreyi değiştir'),
                onTap: _busy ? null : _password,
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Görünüm ayarları'),
                trailing: DropdownButton<ThemeMode>(
                  value: widget.state.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistem'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Aydınlık'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Koyu'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (mode) {
                          if (mode != null) widget.onThemeChanged(mode);
                        },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Bildirimler'),
                onTap: widget.onNotifications,
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Gizlilik Politikası'),
                onTap: () => openCompanyLink(context, companyPrivacy),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Hesabı sil',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _busy ? null : _delete,
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        'Sözleşmelerim',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppGlass.textPrimary(context),
        ),
      ),
      const SizedBox(height: 12),
      CustomerContractCard(
        customer: widget.state.currentCustomer,
        repository: widget.repository,
      ),
      const SizedBox(height: 24),
      Text(
        'İletişim',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppGlass.textPrimary(context),
        ),
      ),
      const SizedBox(height: 12),
      const CompanyContactCard(),
      const SizedBox(height: 12),
      const CompanyLinksCard(),
      const SizedBox(height: 18),
      if (_busy)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        ),
      TextButton.icon(
        onPressed: _busy ? null : widget.onLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Çıkış yap'),
      ),
    ],
  );
}
