import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'models/app_models.dart';
import 'services/app_state.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/customer_notes_screen.dart';
import 'screens/customer/customer_support_screen.dart';
import 'screens/customer/customer_website_screen.dart';
import 'screens/customer/iban_and_statement_sheets.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'widgets/website_blurred_background.dart';

void main() {
  runApp(const SenetTakipApp());
}

class SenetTakipApp extends StatefulWidget {
  const SenetTakipApp({super.key});

  @override
  State<SenetTakipApp> createState() => _SenetTakipAppState();
}

class _SenetTakipAppState extends State<SenetTakipApp> {
  final AppState _appState = AppState();
  static const String _fontFamily = 'Plus Jakarta Sans';

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
          title: 'Demirtürk Mobil',
          debugShowCheckedModeBanner: false,
          scrollBehavior:
              const MaterialScrollBehavior().copyWith(scrollbars: false),
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
                    final phoneHeight =
                        (constraints.maxHeight - 32).clamp(400.0, 1200.0);
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
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.50 : 0.06),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: MediaQuery(
                            data: mq.copyWith(
                              size: Size(440, phoneHeight),
                            ),
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
          home: MainShell(appState: _appState),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState appState;

  const MainShell({super.key, required this.appState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _customerTabIndex = 0;
  int _adminTabIndex = 0;

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
        final topStatusBarSpacing = systemTopInset > 0
            ? systemTopInset + (screenHeight * 0.012).clamp(6.0, 14.0)
            : (screenHeight * 0.032).clamp(18.0, 30.0);

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
            preferredSize: Size.fromHeight(50 + topStatusBarSpacing),
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

                // Üst Bar İçeriği: Katmansız Logo + DEMİRTÜRK / MOBİL + Sağda Bildirimler
                Padding(
                  padding: EdgeInsets.only(
                    top: topStatusBarSpacing,
                    left: 18,
                    right: 16,
                  ),
                  child: SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        // Logonun etrafında kesinlikle katman yok.
                        // Aydınlık modda antrasit üst çizgi (demirturk-emblem-dark.png),
                        // koyu modda beyaz üst çizgi (demirturk-emblem-white.png), alttaki kırmızı sabit.
                        Image.asset(
                          isDark
                              ? 'assets/images/demirturk-emblem-white.png'
                              : 'assets/images/demirturk-emblem-dark.png',
                          width: 24,
                          height: 19,
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
                                  fontSize: 13.5,
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
                                  fontSize: 8.5,
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

                        // Sağ üstte yalnızca Bildirimler
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          pressedOpacity: 0.65,
                          onPressed: () =>
                              showNotificationsSheet(context, widget.appState),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(context),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.bell,
                                  size: 16,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: isCustomer
              ? _buildCustomerBody(
                  bottomNavHeight:
                      58 + (bottomNavSafeSpacing * 0.42).clamp(8.0, 16.0),
                )
              : _buildAdminBody(),
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
            _IosTabItem(
              assetIcon: isDark
                  ? 'assets/images/demirturk-emblem-white.png'
                  : 'assets/images/demirturk-emblem-dark.png',
              label: 'Resmi',
            ),
            const _IosTabItem(
              icon: CupertinoIcons.person_crop_circle,
              activeIcon: CupertinoIcons.person_crop_circle_fill,
              label: 'Hesabım',
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
                ? const Color(0xFF141312).withValues(alpha: 0.62)
                : const Color(0xFFF8F9FB).withValues(alpha: 0.64),
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
                            ? const Color(0xFFF5F3F0)
                            : const Color(0xFF1E293B),
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
                  final activeFg =
                      isDark ? const Color(0xFF121110) : Colors.white;
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
                                item.assetIcon != null
                                    ? Image.asset(
                                        item.assetIcon!,
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        color:
                                            isSelected ? activeFg : inactiveFg,
                                        colorBlendMode: BlendMode.srcIn,
                                      )
                                    : Icon(
                                        isSelected
                                            ? item.activeIcon
                                            : item.icon,
                                        size: 20,
                                        color:
                                            isSelected ? activeFg : inactiveFg,
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
    final Widget page;
    switch (_customerTabIndex) {
      case 0:
        // Başlangıç
        page = CustomerHomeScreen(
          appState: widget.appState,
          onNavigateTab: _switchCustomerTab,
        );
        break;
      case 1:
        // Ödemelerim
        page = CustomerNotesScreen(
          appState: widget.appState,
        );
        break;
      case 2:
        // İletişim
        page = CustomerSupportScreen(
          appState: widget.appState,
        );
        break;
      case 3:
        // Resmi (iframe navbar'ın üstünü kapatmasın diye bottomPadding verilir)
        page = CustomerWebsiteScreen(
          bottomPadding: bottomNavHeight,
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
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (child.key == const ValueKey<int>(3)) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }
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
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_customerTabIndex),
        child: page,
      ),
    );
  }

  Widget _buildAdminBody() {
    return AdminDashboardScreen(
      appState: widget.appState,
      activeTabIndex: _adminTabIndex,
    );
  }

  Widget _buildCustomerSettingsTab() {
    final isDark = AppGlass.isDark(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Sözleşmelerim',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppGlass.textPrimary(context),
            ),
          ),
        ),
        const GlassCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Ayarlar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppGlass.textPrimary(context),
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppGlass.subtleSurface(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark
                      ? CupertinoIcons.moon_stars_fill
                      : CupertinoIcons.sun_max_fill,
                  size: 17,
                  color: AppGlass.textPrimary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Görünüm',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Koyu görünüm' : 'Aydınlık görünüm',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppGlass.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: isDark,
                backgroundColor: AppGlass.subtleSurface(context),
                thumbColor: isDark
                    ? const Color(0xFF332F2B)
                    : Colors.white,
                children: {
                  false: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      'Aydınlık',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                  ),
                  true: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      'Koyu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                  ),
                },
                onValueChanged: (val) {
                  if (val != null && val != isDark) {
                    widget.appState.toggleThemeMode(context);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IosTabItem {
  final IconData? icon;
  final IconData? activeIcon;
  final String? assetIcon;
  final String label;
  final int badgeCount;

  const _IosTabItem({
    this.icon,
    this.activeIcon,
    this.assetIcon,
    required this.label,
    this.badgeCount = 0,
  });
}
