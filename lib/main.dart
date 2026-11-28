import './services/user_facing_error.dart';

import 'dart:ui';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/backend_config.dart';
import 'services/portal_repository.dart';
import 'services/push_notification_service.dart';
import 'services/secure_session_storage.dart';
import 'models/app_models.dart';
import 'services/app_state.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/customer/customer_account_settings.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/customer_notes_screen.dart';
import 'screens/customer/customer_project_screen.dart';
import 'screens/customer/customer_project_showcase.dart';
import 'screens/customer/customer_support_screen.dart';
import 'screens/customer/iban_and_statement_sheets.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_support_inbox_screen.dart';
import 'screens/admin/account_preview_screen.dart';
import 'widgets/website_blurred_background.dart';
import 'widgets/company_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initializeFirebase();
  final backendConfig = BackendConfig.fromEnvironment();
  if (backendConfig.isConfigured) {
    await Supabase.initialize(
      url: backendConfig.url!,
      publishableKey: backendConfig.publishableKey!,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(projectUrl: backendConfig.url!),
      ),
    );
  }
  runApp(const SenetTakipApp());
}

class SenetTakipApp extends StatefulWidget {
  const SenetTakipApp({super.key});

  @override
  State<SenetTakipApp> createState() => _SenetTakipAppState();
}

class _SenetTakipAppState extends State<SenetTakipApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppState _appState = AppState();
  static const String _fontFamily = 'Plus Jakarta Sans';
  bool _isAuthenticated = false;
  bool _startupComplete = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_restorePersistedSession());
    if (BackendConfig.fromEnvironment().isConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
            if (event.event == AuthChangeEvent.signedOut && mounted) {
              _appState.clearSessionData();
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
              setState(() => _isAuthenticated = false);
            }
          });
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _appState.dispose();
    super.dispose();
  }

  Future<void> _restorePersistedSession() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1100));
    final config = BackendConfig.fromEnvironment();
    final user = config.isConfigured
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role, staff_role')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        final dbRole = profile?['role'] as String?;
        final role = switch (profile?['staff_role'] as String?) {
          'sales_advisor' => UserRole.salesAdvisor,
          'accounting' => UserRole.accounting,
          'management' => UserRole.management,
          _ when dbRole == 'admin' => UserRole.admin,
          _ when dbRole == 'customer' => UserRole.customer,
          _ => null,
        };
        if (role != null) {
          _appState.setRole(role);
          _isAuthenticated = true;
        }
      } catch (error) {
        debugPrint(
          userFacingError(
            error,
            fallback:
                'Could not restore the saved session profile. Tekrar deneyin.',
          ),
        );
      }
    }
    await minSplash;
    if (mounted) setState(() => _startupComplete = true);
  }

  void _onAuthenticated(UserRole role) {
    _appState.clearSessionData();
    _appState.setRole(role);
    setState(() => _isAuthenticated = true);
  }

  Future<void> _signOut() async {
    try {
      if (BackendConfig.fromEnvironment().isConfigured &&
          Supabase.instance.client.auth.currentSession != null) {
        try {
          await PushNotificationService(Supabase.instance.client)
              .unregisterCurrentToken();
        } catch (error) {
          debugPrint(
            userFacingError(
              error,
              fallback: 'Could not unregister push device. Tekrar deneyin.',
            ),
          );
        }
        await Supabase.instance.client.auth.signOut();
      }
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Sign out failed remotely; clearing local session. Tekrar deneyin.',
        ),
      );
    } finally {
      _appState.clearSessionData();
      _appState.setRole(UserRole.customer);
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      if (mounted) setState(() => _isAuthenticated = false);
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark ? const Color(0xFF211F1D) : const Color(0xFF1E293B);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: isDark ? const Color(0xFF141312) : const Color(0xFFF8F9FB),
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: seed,
        primary: seed,
        surface: isDark ? const Color(0xFF141312) : const Color(0xFFF8F9FB),
      ),
    );

    const cupertinoFontStyle = TextStyle(fontFamily: _fontFamily);

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: _fontFamily),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: Color(0xFF1E293B),
        textTheme: CupertinoTextThemeData(
          textStyle: cupertinoFontStyle,
          actionTextStyle: cupertinoFontStyle,
          tabLabelTextStyle: cupertinoFontStyle,
          navTitleTextStyle: cupertinoFontStyle,
          navLargeTitleTextStyle: cupertinoFontStyle,
          navActionTextStyle: cupertinoFontStyle,
          pickerTextStyle: cupertinoFontStyle,
          dateTimePickerTextStyle: cupertinoFontStyle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Demirtürk Mobil',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          themeMode: _appState.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final navContent = WebsiteBlurredBackground(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: _fontFamily),
                child: child ?? const SizedBox.shrink(),
              ),
            );

            return ColoredBox(
              color: isDark ? const Color(0xFF0E0D0C) : const Color(0xFFF1F4F9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 540) {
                    final phoneHeight = (constraints.maxHeight - 32).clamp(
                      400.0,
                      1200.0,
                    );
                    final mq = MediaQuery.of(context);
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          width: 440,
                          height: phoneHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF141312)
                                : const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(38),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFFFF8F0)
                                        .withValues(alpha: 0.09)
                                  : const Color(0xFF0F172A)
                                        .withValues(alpha: 0.06),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.50 : 0.06,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: MediaQuery(
                            data: mq.copyWith(size: Size(440, phoneHeight)),
                            child: navContent,
                          ),
                        ),
                      ),
                    );
                  }
                  return navContent;
                },
              ),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 640),
            reverseDuration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) {
              final enteringPortal = child.key == const ValueKey('portal');
              final slide =
                  Tween<Offset>(
                    begin: Offset(0, enteringPortal ? 0.055 : -0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: !_startupComplete
                ? const _StartupBrandScreen(key: ValueKey('startup-brand'))
                : _isAuthenticated
                ? KeyedSubtree(
                    key: const ValueKey('portal'),
                    child: MainShell(appState: _appState, onLogout: _signOut),
                  )
                : KeyedSubtree(
                    key: const ValueKey('auth'),
                    child: AuthScreen(
                      appState: _appState,
                      onAuthenticated: _onAuthenticated,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _StartupBrandScreen extends StatefulWidget {
  const _StartupBrandScreen({super.key});

  @override
  State<_StartupBrandScreen> createState() => _StartupBrandScreenState();
}

class _StartupBrandScreenState extends State<_StartupBrandScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .84,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF141312)
          : const Color(0xFFF8F9FB),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              isDark
                  ? 'assets/images/demirturk-emblem-white.png'
                  : 'assets/images/demirturk-emblem-dark.png',
              width: 116,
              height: 116,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState appState;
  final Future<void> Function() onLogout;
  final bool connectBackend;

  const MainShell({super.key, required this.appState, required this.onLogout, this.connectBackend = true});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _customerTabIndex = 0;
  int _adminTabIndex = 0;

  PortalRepository? _portalRepository;
  PushNotificationService? _pushService;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _notesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _customersSubscription;
  bool _backendDataReady = false;
  bool _customerContractPending = false;
  Object? _backendDataError;
  Map<String, dynamic>? _pendingPush;

  @override
  void initState() {
    super.initState();
    if (widget.connectBackend && BackendConfig.fromEnvironment().isConfigured &&
        Supabase.instance.client.auth.currentUser != null) {
      _portalRepository = PortalRepository(
        Supabase.instance.client,
        staffNotifications: widget.appState.currentRole.isStaff,
      );
      _pushService = PushNotificationService(Supabase.instance.client);
      _notificationSubscription = _portalRepository!
          .watchMyNotifications()
          .listen(
            widget.appState.replaceCustomerNotifications,
            onError: (Object error) => debugPrint(
              userFacingError(
                error,
                fallback: 'Inbox realtime error. Tekrar deneyin.',
              ),
            ),
          );
      unawaited(
        _pushService!.start(
          onMessage: (payload) {
            unawaited(_refreshNotifications());
          },
          onOpened: _openPushNotification,
        ),
      );
      unawaited(_refreshNotifications());
      unawaited(_loadUserPreferences());
      unawaited(_loadPortalData());
      _notesSubscription = _portalRepository!.watchNotes().listen(
        (_) => unawaited(_refreshPortalNotes()),
        onError: (Object error) => debugPrint(
          userFacingError(
            error,
            fallback: 'Notes realtime error. Tekrar deneyin.',
          ),
        ),
      );
      if (widget.appState.currentRole.isStaff) {
        _customersSubscription = _portalRepository!.watchCustomers().listen(
          (_) => unawaited(_refreshCustomers()),
          onError: (Object error) => debugPrint(
            userFacingError(
              error,
              fallback: 'Customers realtime error. Tekrar deneyin.',
            ),
          ),
        );
      } else {
        _customersSubscription = _portalRepository!.watchMyCustomer().listen(
          (_) => unawaited(_refreshMyCustomer()),
          onError: (Object error) => debugPrint(
            userFacingError(
              error,
              fallback: 'Customer realtime error. Tekrar deneyin.',
            ),
          ),
        );
      }
    } else {
      // The staff registration preview does not create a backend session.
      // Mark it ready so the shell can show the staff workspace instead of
      // leaving the user on an endless spinner.
      _backendDataReady = true;
    }
  }

  Future<void> _refreshNotifications() async {
    final repository = _portalRepository;
    if (repository == null) return;
    try {
      widget.appState.replaceCustomerNotifications(
        await repository.loadMyNotifications(),
      );
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Inbox refresh failed. Tekrar deneyin.',
        ),
      );
    }
  }

  Future<void> _refreshPortalNotes() async {
    final repository = _portalRepository;
    if (repository == null) return;
    try {
      await _refreshFinanceData(sync: true);
      final notes = widget.appState.currentRole.canSeePromissoryNotes
          ? await repository.loadNotes()
          : await repository.loadMyNotes();
      widget.appState.replaceBackendNotes(notes);
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Notes refresh failed. Tekrar deneyin.',
        ),
      );
    }
  }

  bool _financeRefreshInProgress = false;
  Future<void> _refreshFinanceData({bool sync = false}) async {
    final repository = _portalRepository;
    if (repository == null || _financeRefreshInProgress) return;
    final userId = repository.currentUserId;
    final customerId = widget.appState.selectedCustomerId;
    _financeRefreshInProgress = true;
    try {
      if (sync &&
          customerId.isNotEmpty &&
          !widget.appState.currentCustomer.contractPending) {
        try {
          await repository.syncCustomerFinance(customerId);
          if (mounted && repository.currentUserId == userId)
            widget.appState.setFinanceError(customerId, null);
        } catch (error) {
          if (mounted && repository.currentUserId == userId)
            widget.appState.setFinanceError(
              customerId,
              userFacingError(
                error,
                fallback: 'Ödeme bilgileri yenilenemedi. Son doğrulanmış bilgiler gösteriliyor.',
              ),
            );
        }
      }
      final rows = await repository.loadFinanceSnapshots();
      if (mounted && repository.currentUserId == userId)
        widget.appState.replaceBackendFinances(rows);
    } finally {
      _financeRefreshInProgress = false;
    }
  }

  Future<void> _refreshCustomers() async {
    final repository = _portalRepository;
    if (repository == null || !widget.appState.currentRole.isStaff) return;
    try {
      final rows = await repository.loadCustomers();
      if (mounted) widget.appState.replaceBackendCustomers(rows);
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Customers refresh failed. Tekrar deneyin.',
        ),
      );
    }
  }

  Future<void> _refreshMyCustomer() async {
    final repository = _portalRepository;
    if (repository == null ||
        !_backendDataReady ||
        widget.appState.currentRole.isStaff)
      return;
    try {
      final row = await repository.loadMyCustomer();
      if (!mounted || row == null) return;
      setState(
        () => _customerContractPending = row['contract_status'] == 'pending',
      );
      widget.appState.replaceBackendCustomers([row]);
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Customer refresh failed. Tekrar deneyin.',
        ),
      );
    }
  }

  Future<void> _loadPortalData() async {
    final repository = _portalRepository;
    if (repository == null) return;
    if (mounted) setState(() => _backendDataReady = false);
    try {
      final banks = await repository.loadBankAccounts().timeout(
        const Duration(seconds: 20),
      );
      if (widget.appState.currentRole.isStaff) {
        final results = await Future.wait([
          repository.loadCustomers().timeout(const Duration(seconds: 20)),
          if (widget.appState.currentRole.canSeePromissoryNotes)
            repository.loadNotes().timeout(const Duration(seconds: 20))
          else
            Future.value(<Map<String, dynamic>>[]),
        ]);
        widget.appState.replaceBackendAdminData(
          customerRows: results[0],
          noteRows: results[1],
          bankRows: banks,
        );
      } else {
        var customer = await repository.loadMyCustomer();
        if (customer == null) {
          final profile = await repository.loadMyProfile();
          await repository.ensureMyCustomerRecord(
            fullName: profile?['full_name']?.toString() ?? '',
          );
          customer = await repository.loadMyCustomer();
        }
        if (customer == null) {
          final profile = await repository.loadMyProfile();
          widget.appState.replaceBackendPendingCustomer(
            name: profile?['full_name']?.toString() ?? 'Müşteri',
            phone: Supabase.instance.client.auth.currentUser?.phone ?? '',
            bankRows: banks,
          );
          if (mounted) {
            setState(() {
              _backendDataReady = true;
              _backendDataError = null;
              _customerContractPending = true;
            });
          }
          return;
        }
        _customerContractPending = customer['contract_status'] == 'pending';
        if (!_customerContractPending) {
          try {
            await repository.syncCustomerFinance(customer['id'].toString());
          } catch (error) {
            widget.appState.setFinanceError(
              customer['id'].toString(),
              userFacingError(
                error,
                fallback: 'Ödeme bilgileri yenilenemedi. Son doğrulanmış bilgiler gösteriliyor.',
              ),
            );
          }
        }
        final notes = await repository.loadMyNotes();
        widget.appState.replaceBackendCustomerData(
          customerRow: customer,
          noteRows: notes,
          bankRows: banks,
        );
      }
      await _refreshFinanceData();
      if (mounted) {
        setState(() {
          _backendDataReady = true;
          _backendDataError = null;
        });
        final pending = _pendingPush;
        _pendingPush = null;
        if (pending != null) _openPushNotification(pending);
      }
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Portal data load failed. Tekrar deneyin.',
        ),
      );
      if (mounted) {
        setState(() {
          _backendDataReady = true;
          _backendDataError = error;
        });
      }
    }
  }

  void _openPushNotification(Map<String, dynamic> payload) {
    final repository = _portalRepository;
    if (!mounted || repository == null) return;
    final recipient = payload['recipient_user_id'];
    if (recipient != null && recipient != repository.currentUserId) return;
    if (!_backendDataReady) {
      _pendingPush = payload;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final staff = widget.appState.currentRole.isStaff;
      final type = payload['type']?.toString();
      final notificationId =
          payload[staff ? 'staff_notification_id' : 'notification_id']
              ?.toString();
      if (notificationId != null) {
        unawaited(
          repository.markNotificationRead(notificationId).catchError((
            Object error,
          ) {
            debugPrint(
              userFacingError(
                error,
                fallback: 'Notification read state failed. Tekrar deneyin.',
              ),
            );
          }),
        );
      }
      if (type == 'message' && payload['ticket_id'] != null) {
        final ticketId = payload['ticket_id'].toString();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(title: const Text('Mesajlar')),
              body: staff
                  ? AdminSupportInboxScreen(
                      repository: repository,
                      initialTicketId: ticketId,
                    )
                  : CustomerSupportScreen(
                      appState: widget.appState,
                      repository: repository,
                      initialTicketId: ticketId,
                    ),
            ),
          ),
        );
        return;
      }
      setState(() {
        if (staff) {
          _adminTabIndex = type == 'contract' ? 2 : 0;
        } else {
          _customerTabIndex = type == 'contract' ? 4 : 1;
        }
      });
      unawaited(_refreshNotifications());
      unawaited(_refreshMyCustomer());
      unawaited(_refreshPortalNotes());
    });
  }

  Future<void> _enablePushNotifications() async {
    try {
      final enabled = await _pushService?.enable() ?? false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Bildirimler açık.' : 'Bildirim iznini telefonunuzun uygulama ayarlarından kontrol edin.',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirimler etkinleştirilemedi. Tekrar deneyin.'),
          ),
        );
    }
  }

  void _showAiComingSoon() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demirtürk AI'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Yakında!'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showStaffProfile() {
    final profileFuture = _portalRepository?.loadMyProfile();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _StaffProfilePage(
          profileFuture: profileFuture,
          role: widget.appState.currentRole,
          localStaffName: widget.appState.localStaffName,
          onLogout: widget.onLogout,
          appState: widget.appState,
          onThemeChanged: _saveThemeMode,
          repository: _portalRepository,
          onEnableNotifications: _enablePushNotifications,
        ),
      ),
    );
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    widget.appState.setThemeMode(mode);
    try {
      await _portalRepository?.saveUserPreferences({'theme_mode': mode.name});
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Appearance preference save failed. Tekrar deneyin.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görünüm tercihi sunucuya kaydedilemedi.'),
          ),
        );
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final repository = _portalRepository;
    if (repository == null) return;
    try {
      final preferences = await repository.loadUserPreferences();
      final mode = switch (preferences['theme_mode']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (mounted) widget.appState.setThemeMode(mode);
    } catch (error) {
      debugPrint(
        userFacingError(
          error,
          fallback: 'Settings load failed. Tekrar deneyin.',
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_pushService?.dispose());
    unawaited(_notificationSubscription?.cancel());
    unawaited(_notesSubscription?.cancel());
    unawaited(_customersSubscription?.cancel());
    super.dispose();
  }

  void _switchCustomerTab(int newIndex) {
    if (newIndex == _customerTabIndex) return;
    setState(() {
      _customerTabIndex = newIndex;
    });
  }

  void _switchAdminTab(int newIndex) {
    if (newIndex == _adminTabIndex) return;
    setState(() {
      _adminTabIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final isCustomer = widget.appState.currentRole == UserRole.customer;
        final isDark = AppGlass.isDark(context);
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;

        final systemTopInset = mediaQuery.viewPadding.top > 0
            ? mediaQuery.viewPadding.top
            : mediaQuery.padding.top;
        final headerScale = (mediaQuery.size.width / 390).clamp(.9, 1.12);
        final headerHeight = 60.0 * headerScale;
        final headerGap = (screenHeight * .005).clamp(3.0, 6.0);
        final topStatusBarSpacing = systemTopInset + headerGap;

        final systemBottomInset = mediaQuery.viewPadding.bottom > 0
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;
        final bottomNavSafeSpacing = systemBottomInset > 0
            ? systemBottomInset + (screenHeight * 0.016).clamp(10.0, 20.0)
            : (screenHeight * 0.032).clamp(20.0, 32.0);

        final mobileContent = Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(headerHeight + headerGap),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Keskin çizgi veya renk ayrımı olmadan, yukarıdan aşağıya doğru
                // yumuşakça eriyen gradyan blur ve ~%10 hafif koyulaşma katmanı
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Color(0xB3FFFFFF),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.58, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.28),
                                      Colors.black.withValues(alpha: 0.10),
                                      Colors.transparent,
                                    ]
                                  : [
                                      const Color(0xFF0F172A)
                                          .withValues(alpha: 0.09),
                                      const Color(0xFF0F172A)
                                          .withValues(alpha: 0.03),
                                      Colors.transparent,
                                    ],
                              stops: const [0.0, 0.62, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Üst Bar İçeriği: Katmansız Logo + DEMİRTÜRK / MOBİL + AI ve Bildirimler
                Padding(
                  padding: EdgeInsets.only(
                    top: topStatusBarSpacing,
                    left: 18,
                    right: 16,
                  ),
                  child: SizedBox(
                    height: headerHeight,
                    child: Row(
                      children: [
                        // Logonun etrafında kesinlikle katman yok.
                        // Aydınlık modda antrasit üst çizgi (demirturk-emblem-dark.png),
                        // koyu modda beyaz üst çizgi (demirturk-emblem-white.png), alttaki kırmızı sabit.
                        Image.asset(
                          isDark
                              ? 'assets/images/demirturk-emblem-white.png'
                              : 'assets/images/demirturk-emblem-dark.png',
                          width: 28.8 * headerScale,
                          height: 22.8 * headerScale,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'DEMİRTÜRK',
                                style: TextStyle(
                                  fontSize: 16.2 * headerScale,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  height: 1.1,
                                  color: AppGlass.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                'MOBİL',
                                style: TextStyle(
                                  fontSize: 10.2 * headerScale,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 3.0,
                                  height: 1.1,
                                  color: AppGlass.textSecondary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          pressedOpacity: 0.65,
                          onPressed: _showAiComingSoon,
                          child: SizedBox(
                            width: 35.2 * headerScale,
                            height: 35.2 * headerScale,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  isDark
                                      ? 'assets/images/demirturk-emblem-white.png'
                                      : 'assets/images/demirturk-emblem-dark.png',
                                  width: 20,
                                  height: 19.8 * headerScale,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  top: 0,
                                  right: 1,
                                  child: Icon(
                                    CupertinoIcons.sparkles,
                                    size: 12.1 * headerScale,
                                    color: const Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          pressedOpacity: 0.65,
                          onPressed: () => showNotificationsSheet(
                            context,
                            widget.appState,
                            repository: _portalRepository,
                          ),
                          child: Container(
                            width: 35.2 * headerScale,
                            height: 35.2 * headerScale,
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(context),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.bell,
                                  size: 17.6 * headerScale,
                                  color: AppGlass.textPrimary(context),
                                ),
                                if (widget.appState.unreadNotificationCount > 0)
                                  Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Container(
                                      width: 6.5,
                                      height: 6.5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE11D48),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!isCustomer) ...[
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            pressedOpacity: 0.65,
                            onPressed: _showStaffProfile,
                            child: Container(
                              width: 35.2 * headerScale,
                              height: 35.2 * headerScale,
                              decoration: BoxDecoration(
                                color: AppGlass.subtleSurface(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.person_crop_circle_fill,
                                size: 19,
                                color: AppGlass.textPrimary(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body:
              BackendConfig.fromEnvironment().isConfigured && !_backendDataReady
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _backendDataError != null && isCustomer
              ? _BackendLoadError(
                  error: _backendDataError!,
                  onRetry: _loadPortalData,
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _buildScreenTransition,
                  child: isCustomer
                      ? KeyedSubtree(
                          key: const ValueKey('customer-workspace'),
                          child: _buildCustomerBody(
                            bottomNavHeight:
                                58 +
                                (bottomNavSafeSpacing * 0.42).clamp(8.0, 16.0),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('admin-workspace'),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 440),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: _buildScreenTransition,
                            child: KeyedSubtree(
                              key: ValueKey<int>(_adminTabIndex),
                              child: _buildAdminBody(),
                            ),
                          ),
                        ),
                ),
          bottomNavigationBar: _buildBottomTabBar(
            context: context,
            isCustomer: isCustomer,
            isDark: isDark,
            bottomNavSafeSpacing: bottomNavSafeSpacing,
          ),
        );

        return mobileContent;
      },
    );
  }

  Widget _buildScreenTransition(Widget child, Animation<double> animation) {
    final position = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: position, child: child),
    );
  }

  Widget _buildBottomTabBar({
    required BuildContext context,
    required bool isCustomer,
    required bool isDark,
    required double bottomNavSafeSpacing,
  }) {
    final activeIndex = isCustomer ? _customerTabIndex : _adminTabIndex;
    final pendingCount = widget.appState.pendingVerificationCount;

    final items = isCustomer
        ? [
            const _IosTabItem(
              icon: CupertinoIcons.house,
              activeIcon: CupertinoIcons.house_fill,
              label: 'Başlangıç',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.doc_text,
              activeIcon: CupertinoIcons.doc_text_fill,
              label: 'Ödemelerim',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.chat_bubble_2,
              activeIcon: CupertinoIcons.chat_bubble_2_fill,
              label: 'İletişim',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.building_2_fill,
              activeIcon: CupertinoIcons.building_2_fill,
              label: 'Evim',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.person_crop_circle,
              activeIcon: CupertinoIcons.person_crop_circle_fill,
              label: 'Hesabım',
            ),
          ]
        : widget.appState.currentRole.isSalesAdvisor
        ? const [
            _IosTabItem(
              icon: CupertinoIcons.person_2,
              activeIcon: CupertinoIcons.person_2_fill,
              label: 'Müşteriler',
            ),
            _IosTabItem(
              icon: CupertinoIcons.building_2_fill,
              activeIcon: CupertinoIcons.building_2_fill,
              label: 'Süreçler',
            ),
            _IosTabItem(
              icon: CupertinoIcons.bubble_left_bubble_right,
              activeIcon: CupertinoIcons.bubble_left_bubble_right_fill,
              label: 'Mesajlar',
            ),
            _IosTabItem(
              icon: CupertinoIcons.archivebox,
              activeIcon: CupertinoIcons.archivebox_fill,
              label: 'Kapananlar',
            ),
          ]
        : [
            _IosTabItem(
              icon: CupertinoIcons.checkmark_seal,
              activeIcon: CupertinoIcons.checkmark_seal_fill,
              label: 'Onay & Özet',
              badgeCount: pendingCount,
            ),
            const _IosTabItem(
              icon: CupertinoIcons.doc_on_doc,
              activeIcon: CupertinoIcons.doc_on_doc_fill,
              label: 'Senetler',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.person_2,
              activeIcon: CupertinoIcons.person_2_fill,
              label: 'Müşteriler',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.bubble_left_bubble_right,
              activeIcon: CupertinoIcons.bubble_left_bubble_right_fill,
              label: 'Mesajlar',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.archivebox,
              activeIcon: CupertinoIcons.archivebox_fill,
              label: 'Kapananlar',
            ),
          ];

    final bottomPad = (bottomNavSafeSpacing * 0.42).clamp(8.0, 16.0);

    // Gerçek Frosted Glass: Container ve içerik doğrudan BackdropFilter'ın child'ı
    // olarak çizilir; böylece Flutter motoru tüm navbar alanını gerçek Gaussian blur ile blurlar.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
        child: Container(
          height: 58 + bottomPad,
          padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141312).withValues(alpha: 0.48)
                : const Color(0xFFF8F9FB).withValues(alpha: 0.48),
          ),
          child: Stack(
            children: [
              // Seçili sekmeye doğru sağa/sola kayan aktif gösterge
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    items.length > 1
                        ? -1.0 + (2.0 * activeIndex / (items.length - 1))
                        : 0.0,
                    0.0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1.0 / items.length,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFF5F3F0).withValues(alpha: .9)
                            : const Color(0xFF1E293B).withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (idx) {
                  final item = items[idx];
                  final isSelected = idx == activeIndex;
                  final activeFg = isDark
                      ? const Color(0xFF121110)
                      : Colors.white;
                  final inactiveFg = isDark
                      ? const Color(0xFF9C958C)
                      : const Color(0xFF64748B);

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isCustomer) {
                          _switchCustomerTab(idx);
                        } else {
                          _switchAdminTab(idx);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 20,
                                  color: isSelected ? activeFg : inactiveFg,
                                ),
                                if (item.badgeCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -3,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE11D48),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: -0.2,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected ? activeFg : inactiveFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerBody({required double bottomNavHeight}) {
    final showProjectShowcase =
        _customerTabIndex == 0 &&
        widget.appState.currentCustomer.contractNo.trim().isEmpty;
    final Widget page;
    switch (_customerTabIndex) {
      case 0:
        // Başlangıç
        page = showProjectShowcase
            ? CustomerProjectShowcase(
                bottomPadding: bottomNavHeight,
                onContact: () => _switchCustomerTab(2),
              )
            : CustomerHomeScreen(
                appState: widget.appState,
                onNavigateTab: _switchCustomerTab,
                repository: _portalRepository,
              );
        break;
      case 1:
        // Ödemelerim
        page = CustomerNotesScreen(
          appState: widget.appState,
          repository: _portalRepository,
        );
        break;
      case 2:
        // İletişim
        page = CustomerSupportScreen(
          appState: widget.appState,
          repository: _portalRepository,
        );
        break;
      case 3:
        // Evim: müşterinin proje ve bağımsız bölüm bilgileri.
        page = CustomerProjectScreen(
          appState: widget.appState,
          bottomPadding: bottomNavHeight,
          repository: _portalRepository,
        );
        break;
      case 4:
        // Hesabım -> Sözleşmelerim & Ayarlar Menüsü
        page = _buildCustomerSettingsTab();
        break;
      default:
        page = CustomerHomeScreen(
          appState: widget.appState,
          onNavigateTab: _switchCustomerTab,
          repository: _portalRepository,
        );
        break;
    }

    final content = _customerContractPending
        ? Column(
            children: [
              _buildPendingContractBanner(),
              Expanded(child: page),
            ],
          )
        : page;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 460),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey<int>(_customerTabIndex);
        // Yeni sayfa aşağıdan yukarıya (bottom-to-top) kayarak gelir
        final beginOffset = isIncoming
            ? const Offset(0.0, 0.14)
            : const Offset(0.0, -0.04);

        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_customerTabIndex),
        child: content,
      ),
    );
  }

  Widget _buildPendingContractBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFF9F0A).withValues(alpha: .12),
      border: Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: .32)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          CupertinoIcons.doc_text_search,
          color: Color(0xFFFF9F0A),
          size: 17,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sözleşmeniz henüz atanmadı. Atandığında bilgilerini ve ödemelerinizi görebilirsiniz.',
            style: TextStyle(
              color: AppGlass.isDark(context)
                  ? const Color(0xFFFFE2B5)
                  : const Color(0xFF503500),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAdminBody() {
    final closedIndex = widget.appState.currentRole.isSalesAdvisor ? 3 : 4;
    if (_adminTabIndex == closedIndex && _portalRepository == null) {
      return const Center(
        child: Text('Kapanan sohbet arşivi için sunucu bağlantısı gerekli.'),
      );
    }
    return AdminDashboardScreen(
      appState: widget.appState,
      activeTabIndex: _adminTabIndex,
      repository: _portalRepository,
      onPreviewCustomer: (customer) {
        final repository = _portalRepository;
        if (repository == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CustomerPreviewScreen(repository: repository, id: customer.id),
          ),
        );
      },
    );
  }

  Widget _buildCustomerSettingsTab() => CustomerAccountSettings(
    state: widget.appState,
    repository: _portalRepository,
    onLogout: widget.onLogout,
    onUpdated: _refreshMyCustomer,
    onThemeChanged: _saveThemeMode,
    onNotifications: _enablePushNotifications,
  );
}

class _StaffProfilePage extends StatelessWidget {
  const _StaffProfilePage({
    required this.profileFuture,
    required this.role,
    required this.localStaffName,
    required this.onLogout,
    required this.appState,
    required this.onThemeChanged,
    required this.repository,
    required this.onEnableNotifications,
  });

  final Future<Map<String, dynamic>?>? profileFuture;
  final UserRole role;
  final String? localStaffName;
  final Future<void> Function() onLogout;
  final AppState appState;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final PortalRepository? repository;
  final Future<void> Function() onEnableNotifications;

  String get _roleLabel => switch (role) {
    UserRole.salesAdvisor => 'Satış Danışmanı',
    UserRole.accounting => 'Muhasebe',
    UserRole.management || UserRole.admin => 'Yönetim',
    UserRole.customer => 'Müşteri',
  };

  String get _idLabel => switch (role) {
    UserRole.salesAdvisor => 'Danışman ID',
    UserRole.accounting => 'Muhasebe ID',
    UserRole.management || UserRole.admin => 'Yönetici ID',
    UserRole.customer => 'Hesap ID',
  };

  @override
  Widget build(BuildContext context) {
    final textColor = AppGlass.textPrimary(context);
    final mutedColor = AppGlass.textSecondary(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Icon(CupertinoIcons.back, color: textColor),
        ),
        title: Text(
          'Ayarlar',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: profileFuture ?? Future<Map<String, dynamic>?>.value(),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final currentUser = BackendConfig.fromEnvironment().isConfigured
                ? Supabase.instance.client.auth.currentUser
                : null;
            final metadataName =
                (currentUser?.userMetadata ??
                const <String, dynamic>{})['full_name'];
            final profileName = profile?['full_name']?.toString().trim();
            final name = localStaffName?.isNotEmpty == true
                ? localStaffName!
                : profileName?.isNotEmpty == true
                ? profileName!
                : (metadataName?.toString().trim().isNotEmpty == true
                      ? metadataName.toString().trim()
                      : 'Ad soyad');
            final staffId = profile?['staff_id']?.toString().trim();

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppGlass.dividerColor(context),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.person_crop_circle_fill,
                        size: 48,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _roleLabel,
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: AppGlass.dividerColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _idLabel,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (localStaffName?.isNotEmpty == true)
                            Text(
                              'Supabase hesabı gerekli',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const CupertinoActivityIndicator()
                          else
                            Text(
                              staffId?.isNotEmpty == true
                                  ? staffId!
                                  : 'ID bekleniyor',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListenableBuilder(
                      listenable: appState,
                      builder: (context, _) => ListTile(
                        leading: const Icon(Icons.brightness_6_outlined),
                        title: const Text('Görünüm'),
                        subtitle: Text(_themeLabel(appState.themeMode)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final mode = await showDialog<ThemeMode>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Görünüm'),
                              children: [
                                for (final mode in ThemeMode.values)
                                  SimpleDialogOption(
                                    onPressed: () =>
                                        Navigator.pop(context, mode),
                                    child: Text(_themeLabel(mode)),
                                  ),
                              ],
                            ),
                          );
                          if (mode != null) await onThemeChanged(mode);
                        },
                      ),
                    ),
                    if ((role == UserRole.management ||
                            role == UserRole.admin) &&
                        staffId?.startsWith('Y') == true &&
                        repository != null)
                      ListTile(
                        leading: const Icon(Icons.people_outline),
                        title: const Text('Diğer hesaplar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PortalAccountsScreen(repository: repository!),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const CompanyLinksCard(),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Bildirimler'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onEnableNotifications,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFFE11D48).withValues(alpha: .12),
                        onPressed: () => unawaited(onLogout()),
                        child: const Text(
                          'Çıkış yap',
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Sistem',
    ThemeMode.light => 'Aydınlık',
    ThemeMode.dark => 'Koyu',
  };
}

class _BackendLoadError extends StatelessWidget {
  const _BackendLoadError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Color(0xFFE11D48),
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            'Sunucu verileri yüklenemedi',
            style: TextStyle(
              color: AppGlass.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppGlass.textSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('Yeniden dene'),
          ),
        ],
      ),
    ),
  );
}

class _IosTabItem {
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final int badgeCount;

  const _IosTabItem({
    this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}
