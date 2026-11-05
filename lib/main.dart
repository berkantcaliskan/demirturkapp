import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'models/app_models.dart';
import 'services/app_state.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/customer_notes_screen.dart';
import 'screens/customer/customer_support_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'DemirtürkApp',
          debugShowCheckedModeBanner: false,
          themeMode: _appState.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
             fontFamily: '.SF Pro Text',
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.light,
              seedColor: const Color(0xFF0A84FF),
              primary: const Color(0xFF0A84FF),
            ),
            cupertinoOverrideTheme: const CupertinoThemeData(
              primaryColor: Color(0xFF0A84FF),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: '.SF Pro Text',
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF0A84FF),
              primary: const Color(0xFF0A84FF),
            ),
            cupertinoOverrideTheme: const CupertinoThemeData(
              primaryColor: Color(0xFF0A84FF),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final isCustomer = widget.appState.currentRole == UserRole.customer;
        final isDark = AppGlass.isDark(context);
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;

        // Her telefonun kendi ekran boyutuna ve sistem bildirim çubuğuna göre duyarlı iOS üst boşluğu
        final systemTopInset = mediaQuery.viewPadding.top > 0
            ? mediaQuery.viewPadding.top
            : mediaQuery.padding.top;
        final topStatusBarSpacing = systemTopInset > 0
            ? systemTopInset + (screenHeight * 0.012).clamp(6.0, 14.0)
            : (screenHeight * 0.035).clamp(22.0, 36.0);

        // Ana ekran çizgisi (iPhone Home Indicator) ile katiyen çakışmaması için
        // her telefonun boyutuna göre duyarlı alt yükseltme boşluğu
        final systemBottomInset = mediaQuery.viewPadding.bottom > 0
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;
        final bottomNavSafeSpacing = systemBottomInset > 0
            ? systemBottomInset + (screenHeight * 0.016).clamp(10.0, 20.0)
            : (screenHeight * 0.032).clamp(20.0, 32.0);

        final mobileContent = WebsiteBlurredBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: false,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60 + topStatusBarSpacing),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: topStatusBarSpacing,
                      left: 16,
                      right: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF090D14).withValues(alpha: 0.44)
                          : Colors.white.withValues(alpha: 0.16),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white
                              .withValues(alpha: isDark ? 0.14 : 0.28),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.10 : 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: isDark ? 0.18 : 0.35),
                                width: 0.6,
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/demirturk-emblem-white.png',
                              width: 28,
                              height: 22,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'DemirtürkApp',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  isCustomer
                                      ? 'Demirtürk İnşaat • Müşteri Portalı'
                                      : 'Demirtürk İnşaat • Yönetim Paneli',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Gündüz / Gece Modu iOS Glass Butonu
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            pressedOpacity: 0.65,
                            onPressed: () =>
                                widget.appState.toggleThemeMode(context),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: isDark ? 0.12 : 0.20),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: isDark ? 0.20 : 0.38),
                                  width: 0.6,
                                ),
                              ),
                              child: Icon(
                                isDark
                                    ? CupertinoIcons.sun_max_fill
                                    : CupertinoIcons.moon_stars_fill,
                                size: 17,
                                color: isDark
                                    ? const Color(0xFFFFD60A)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Yönetici / Müşteri Geçiş iOS Capsule Butonu
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            pressedOpacity: 0.7,
                            onPressed: () {
                              widget.appState.setRole(
                                isCustomer ? UserRole.admin : UserRole.customer,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isCustomer
                                      ? [
                                          const Color(0xFF0A84FF)
                                              .withValues(alpha: 0.85),
                                          const Color(0xFF0066CC)
                                              .withValues(alpha: 0.75),
                                        ]
                                      : [
                                          const Color(0xFFFF9F0A)
                                              .withValues(alpha: 0.88),
                                          const Color(0xFFD97706)
                                              .withValues(alpha: 0.78),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCustomer
                                        ? CupertinoIcons.shield_lefthalf_fill
                                        : CupertinoIcons.person_crop_circle,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isCustomer
                                        ? 'Yöneticiye Geç'
                                        : 'Müşteriye Geç',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: Colors.white,
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
                ),
              ),
            ),
            body: isCustomer ? _buildCustomerBody() : _buildAdminBody(),
            bottomNavigationBar: _buildIosFrostedTabBar(
              context: context,
              isCustomer: isCustomer,
              isDark: isDark,
              bottomNavSafeSpacing: bottomNavSafeSpacing,
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 540) {
              return WebsiteBlurredBackground(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      width: 440,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 36,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: mobileContent,
                    ),
                  ),
                ),
              );
            }
            return mobileContent;
          },
        );
      },
    );
  }

  Widget _buildIosFrostedTabBar({
    required BuildContext context,
    required bool isCustomer,
    required bool isDark,
    required double bottomNavSafeSpacing,
  }) {
    final activeIndex = isCustomer ? _customerTabIndex : _adminTabIndex;
    final pendingCount = widget.appState.pendingVerificationCount;

    final items = isCustomer
        ? const [
            _IosTabItem(
              icon: CupertinoIcons.square_grid_2x2,
              activeIcon: CupertinoIcons.square_grid_2x2_fill,
              label: 'Özet',
            ),
            _IosTabItem(
              icon: CupertinoIcons.doc_text,
              activeIcon: CupertinoIcons.doc_text_fill,
              label: 'Senetlerim',
            ),
            _IosTabItem(
              icon: CupertinoIcons.chat_bubble_2,
              activeIcon: CupertinoIcons.chat_bubble_2_fill,
              label: 'İletişim & Destek',
            ),
            _IosTabItem(
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: 8,
            bottom: bottomNavSafeSpacing,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF080C12).withValues(alpha: 0.56)
                : Colors.white.withValues(alpha: 0.18),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.35),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: List.generate(items.length, (idx) {
              final item = items[idx];
              final isSelected = idx == activeIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (isCustomer) {
                        _customerTabIndex = idx;
                      } else {
                        _adminTabIndex = idx;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 23,
                                color: isSelected
                                    ? const Color(0xFF64D2FF)
                                    : Colors.white.withValues(alpha: 0.60),
                              ),
                            ),
                            if (item.badgeCount > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: -0.2,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerBody() {
    switch (_customerTabIndex) {
      case 0:
        return CustomerHomeScreen(
          appState: widget.appState,
          onNavigateTab: (tab) => setState(() => _customerTabIndex = tab),
        );
      case 1:
        return CustomerNotesScreen(appState: widget.appState);
      case 2:
        return CustomerSupportScreen(appState: widget.appState);
      case 3:
        return _buildCustomerProfileTab();
      default:
        return CustomerHomeScreen(
          appState: widget.appState,
          onNavigateTab: (tab) => setState(() => _customerTabIndex = tab),
        );
    }
  }

  Widget _buildAdminBody() {
    return AdminDashboardScreen(
      appState: widget.appState,
      activeTabIndex: _adminTabIndex,
    );
  }

  Widget _buildCustomerProfileTab() {
    final customer = widget.appState.currentCustomer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0A84FF).withValues(alpha: 0.45),
                          const Color(0xFF64D2FF).withValues(alpha: 0.25),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      customer.name.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppGlass.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Sözleşme No: ${customer.contractNo}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppGlass.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: AppGlass.dividerColor(context)),
              ),
              _buildProfileItem(
                CupertinoIcons.person_badge_plus,
                'TC Kimlik / Vergi No',
                customer.tcOrTaxNo,
              ),
              _buildProfileItem(
                CupertinoIcons.phone_fill,
                'Kayıtlı Telefon',
                customer.phone,
              ),
              _buildProfileItem(
                CupertinoIcons.mail_solid,
                'E-Posta Adresi',
                customer.email,
              ),
              _buildProfileItem(
                CupertinoIcons.location_solid,
                'Proje / Daire & Tebligat Adresi',
                customer.address,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _buildIosActionRow(
                icon: CupertinoIcons.doc_richtext,
                iconBgColor: const Color(0xFF0A84FF),
                title: 'Resmi Cari & Senet Hesap Ekstresi',
                subtitle:
                    'Tüm ödenen ve kalan senetlerinizin dökümünü görüntüleyin',
                onTap: () =>
                    showAccountStatementDialog(context, widget.appState),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(height: 1, color: AppGlass.dividerColor(context)),
              ),
              _buildIosActionRow(
                icon: CupertinoIcons.building_2_fill,
                iconBgColor: const Color(0xFF30D158),
                title: 'Şirket Banka & IBAN Hesapları',
                subtitle: 'Havale / FAST / EFT için anlaşmalı banka bilgileri',
                onTap: () => showIbanSheet(context, widget.appState),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(height: 1, color: AppGlass.dividerColor(context)),
              ),
              _buildIosActionRow(
                icon: CupertinoIcons.shield_lefthalf_fill,
                iconBgColor: const Color(0xFFFF9F0A),
                title: 'Şirket / Yönetici Paneline Geç',
                subtitle:
                    'Senet tanımlama, dekont onaylama ve müşteri mesajlarını yanıtlama',
                onTap: () => widget.appState.setRole(UserRole.admin),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIosActionRow({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      pressedOpacity: 0.65,
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppGlass.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: AppGlass.textMuted(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppGlass.subtleSurface(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppGlass.accentBlue(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppGlass.textMuted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IosTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const _IosTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}
