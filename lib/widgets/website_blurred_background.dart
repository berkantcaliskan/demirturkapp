import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WebsiteSlideData {
  final String title;
  final String subtitle;
  final String location;
  final String badge;
  final String stats;
  final String imageAsset;

  const WebsiteSlideData({
    required this.title,
    required this.subtitle,
    required this.location,
    required this.badge,
    required this.stats,
    required this.imageAsset,
  });
}

class WebsiteBlurredBackground extends StatefulWidget {
  final Widget child;

  const WebsiteBlurredBackground({
    super.key,
    required this.child,
  });

  @override
  State<WebsiteBlurredBackground> createState() =>
      _WebsiteBlurredBackgroundState();
}

class _WebsiteBlurredBackgroundState extends State<WebsiteBlurredBackground> {
  int _activeIndex = 0;
  Timer? _slideTimer;

  static const List<WebsiteSlideData> _slides = [
    WebsiteSlideData(
      title: 'Yeni Şehir Etapları',
      subtitle: 'Doğal taşın ilhamıyla prestijli bir yaşam',
      location: 'Yalı Mah., Karasu • Denize 800m',
      badge: 'LÜKS KONUT KOMPLEKSİ • 3 ETAP',
      stats: '246 Daire • 40 Ay Elden Senet',
      imageAsset: 'assets/images/yenisehirforweb.jpeg',
    ),
    WebsiteSlideData(
      title: 'Asel Doğa Evleri',
      subtitle: 'Şehir ve doğayı en sade çizgiyle ayıran yaşam alanı',
      location: 'Aziziye Mah., Karasu • Denize 850m',
      badge: 'HAVUZLU YAŞAM KOMPLEKSİ',
      stats: '57 Daire • 40 Ay Elden Senet',
      imageAsset: 'assets/images/aselforweb.jpeg',
    ),
    WebsiteSlideData(
      title: 'Almina Evleri',
      subtitle: 'Şehir hayatının hiçbir zaman aksamadığı bir yaşam alanı',
      location: 'Yalı Mah., Plaj Cd., Karasu',
      badge: 'SAHİL REZİDANSI',
      stats: '33 Daire • 36 Ay Elden Senet',
      imageAsset: 'assets/images/alminaforweb.jpeg',
    ),
    WebsiteSlideData(
      title: 'Seaside House',
      subtitle: 'Nehir ve Karadeniz, muhteşem bir konumda bir araya geliyor',
      location: 'Yeni Mahalle, Karasu • Plaja 100m',
      badge: 'TAMAMLANAN PROJE',
      stats: '12 Daire • Eksiksiz Teslim',
      imageAsset: 'assets/images/seasideforweb.jpeg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) {
        setState(() {
          _activeIndex = (_activeIndex + 1) % _slides.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSlide = _slides[_activeIndex];
    final nextSlide = _slides[(_activeIndex + 1) % _slides.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base corporate anthracite background (#1A2026)
        const ColoredBox(color: Color(0xFF1A2026)),

        // 2. Website Wallpaper Layer (%20 azaltılmış blur ile kartların kendi Frosted Glass kırılımını öne çıkarır)
        ClipRect(
          child: RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 16.0,
                sigmaY: 16.0,
                tileMode: TileMode.clamp,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1200),
                    child: SizedBox.expand(
                      key: ValueKey<String>(activeSlide.imageAsset),
                      child: Image.asset(
                        activeSlide.imageAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),

                  // Ambient iOS light blooms so scrolling glass cards refract rich colors
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0A84FF).withValues(
                              alpha: isDark ? 0.30 : 0.38,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: -40,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF9F0A).withValues(
                              alpha: isDark ? 0.22 : 0.30,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Website Content Composition in background
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/demirturk-emblem-white.png',
                                width: 42,
                                height: 42,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'DEMİRTÜRK İNŞAAT • KARASU',
                                  style: TextStyle(
                                    color: Color(0xFFFFFFF1),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              activeSlide.badge,
                              style: const TextStyle(
                                color: Color(0xFFFFFFF1),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            activeSlide.title,
                            style: const TextStyle(
                              color: Color(0xFFFFFFF1),
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeSlide.subtitle,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: SizedBox(
                                    height: 150,
                                    child: Image.asset(
                                      nextSlide.imageAsset,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  height: 150,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C2126)
                                        .withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFFFFFF1)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '40 AY ELDEN SENET',
                                        style: TextStyle(
                                          color: Color(0xFFFBBF24),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        '1.650+ Konut • 28+ Proje • Kredisiz & Kefilsiz',
                                        style: TextStyle(
                                          color: Color(0xFFFFFFF1),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Subtle iOS Atmospheric Veil
        // Gündüz modunda daha aydınlık/ferah, gece modunda hafif karartılmış derinlik
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0B0F14).withValues(alpha: 0.50),
                      const Color(0xFF0B0F14).withValues(alpha: 0.38),
                      const Color(0xFF070A0E).withValues(alpha: 0.58),
                    ]
                  : [
                      const Color(0xFF1E2630).withValues(alpha: 0.24),
                      const Color(0xFF1E2630).withValues(alpha: 0.16),
                      const Color(0xFF141A22).withValues(alpha: 0.30),
                    ],
            ),
          ),
        ),

        // 4. Foreground iOS Application Content
        widget.child,
      ],
    );
  }
}

enum GlassCardTone {
  standard,
  hero,
  urgentRed,
  infoBlue,
  warningAmber,
}

/// iOS 18 / visionOS Vibrancy & Frosted Glass Token System
class AppGlass {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Gerçek iOS Frosted Glass üzerinde kristal netliğinde okunabilirlik için
  // Apple HIG Vibrancy (ışıklı beyaz/krem hiyerarşisi)
  static Color textPrimary(BuildContext context) => const Color(0xFFFFFFFF);

  static Color textSecondary(BuildContext context) =>
      Colors.white.withValues(alpha: isDark(context) ? 0.80 : 0.88);

  static Color textMuted(BuildContext context) =>
      Colors.white.withValues(alpha: isDark(context) ? 0.58 : 0.70);

  static Color accentBlue(BuildContext context) =>
      const Color(0xFF64D2FF); // iOS System Cyan-Blue

  static Color systemBlue(BuildContext context) =>
      const Color(0xFF0A84FF); // iOS System Blue

  static Color subtleSurface(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.16);

  static Color dividerColor(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.22);
}

/// Gerçek iPhone (iOS / visionOS) Frosted Glass Kart Bileşeni
/// - Gündüz Modu: Hafif aydınlatılmış yarı saydam buzlu cam (White 14% - 24% + Specular Rim)
/// - Gece Modu: Hafif karartılmış yarı saydam buzlu cam (Smoked Black 32% - 44% + Specular Rim)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final GlassCardTone tone;
  final Color? customBorderColor;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22.0,
    this.tone = GlassCardTone.standard,
    this.customBorderColor,
    this.blurSigma = 26.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);

    List<Color> gradientColors;
    Color borderColor;

    switch (tone) {
      case GlassCardTone.hero:
        if (isDark) {
          // Gece modunda hafif karartılmış safir buzlu cam
          gradientColors = [
            const Color(0xFF0A1220).withValues(alpha: 0.48),
            const Color(0xFF0A84FF).withValues(alpha: 0.18),
            const Color(0xFF070B12).withValues(alpha: 0.42),
          ];
          borderColor = Colors.white.withValues(alpha: 0.24);
        } else {
          // Gündüz modunda hafif aydınlatılmış kristal buzlu cam
          gradientColors = [
            Colors.white.withValues(alpha: 0.28),
            const Color(0xFF64D2FF).withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.16),
          ];
          borderColor = Colors.white.withValues(alpha: 0.52);
        }
        break;
      case GlassCardTone.urgentRed:
        if (isDark) {
          gradientColors = [
            const Color(0xFF280B10).withValues(alpha: 0.46),
            const Color(0xFFFF453A).withValues(alpha: 0.16),
          ];
          borderColor = const Color(0xFFFF453A).withValues(alpha: 0.42);
        } else {
          gradientColors = [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFFFF453A).withValues(alpha: 0.20),
          ];
          borderColor = const Color(0xFFFF6961).withValues(alpha: 0.55);
        }
        break;
      case GlassCardTone.infoBlue:
        if (isDark) {
          gradientColors = [
            const Color(0xFF081629).withValues(alpha: 0.46),
            const Color(0xFF0A84FF).withValues(alpha: 0.16),
          ];
          borderColor = const Color(0xFF64D2FF).withValues(alpha: 0.36);
        } else {
          gradientColors = [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFF0A84FF).withValues(alpha: 0.18),
          ];
          borderColor = Colors.white.withValues(alpha: 0.50);
        }
        break;
      case GlassCardTone.warningAmber:
        if (isDark) {
          gradientColors = [
            const Color(0xFF241707).withValues(alpha: 0.46),
            const Color(0xFFFF9F0A).withValues(alpha: 0.16),
          ];
          borderColor = const Color(0xFFFFD60A).withValues(alpha: 0.38);
        } else {
          gradientColors = [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFFFF9F0A).withValues(alpha: 0.18),
          ];
          borderColor = const Color(0xFFFFD60A).withValues(alpha: 0.52);
        }
        break;
      case GlassCardTone.standard:
        if (isDark) {
          // Gece modunda hafif karartılmış gerçek Frosted Glass
          gradientColors = [
            const Color(0xFF0B0F16).withValues(alpha: 0.44),
            const Color(0xFF070A0F).withValues(alpha: 0.32),
          ];
          borderColor = Colors.white.withValues(alpha: 0.18);
        } else {
          // Gündüz modunda hafif aydınlatılmış gerçek Frosted Glass
          gradientColors = [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.13),
          ];
          borderColor = Colors.white.withValues(alpha: 0.45);
        }
        break;
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: customBorderColor ?? borderColor,
                  width: 0.8,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS tarzı Frosted Glass veya Sistem Mavisi/Kırmızısı/Yeşili Buton
class IosGlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData? icon;
  final String label;
  final Color? color;
  final bool isDestructive;
  final bool isSecondaryGlass;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const IosGlassButton({
    super.key,
    required this.onTap,
    this.icon,
    required this.label,
    this.color,
    this.isDestructive = false,
    this.isSecondaryGlass = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    this.borderRadius = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final baseColor = isDestructive
        ? const Color(0xFFFF453A)
        : (color ?? const Color(0xFF0A84FF));

    final bgColors = isSecondaryGlass
        ? [
            Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
            Colors.white.withValues(alpha: isDark ? 0.07 : 0.14),
          ]
        : [
            baseColor.withValues(alpha: 0.90),
            baseColor.withValues(alpha: 0.76),
          ];

    final rimColor = isSecondaryGlass
        ? Colors.white.withValues(alpha: isDark ? 0.22 : 0.45)
        : Colors.white.withValues(alpha: 0.35);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.72,
      onPressed: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: rimColor, width: 0.8),
          boxShadow: isSecondaryGlass
              ? null
              : [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS tarzı Frosted Glass Alt Pencere (Modal Bottom Sheet)
class IosGlassSheet extends StatelessWidget {
  final Widget child;
  final double? maxHeightFactor;

  const IosGlassSheet({
    super.key,
    required this.child,
    this.maxHeightFactor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final sheetContent = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF121822).withValues(alpha: 0.82),
                      const Color(0xFF0B0F16).withValues(alpha: 0.88),
                    ]
                  : [
                      const Color(0xFF26303D).withValues(alpha: 0.72),
                      const Color(0xFF1B232E).withValues(alpha: 0.82),
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );

    if (maxHeightFactor != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * maxHeightFactor!,
        ),
        child: sheetContent,
      );
    }
    return sheetContent;
  }
}
