import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Beyaz/ferah zemin üzerinde, ekranın altından yukarı doğru yüzen,
/// ekranın yarısını geçmeyen ve çok hafif/az renkli (minimal pastel)
/// gradyan geçişlerinden oluşan Arka Plan Bileşeni.
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

class _WebsiteBlurredBackgroundState extends State<WebsiteBlurredBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _BottomFloatingPastelPainter(
                  progress: _controller.value,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BottomFloatingPastelPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const _BottomFloatingPastelPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = progress * 2 * math.pi;
    final shortSide = size.shortestSide == 0 ? 400.0 : size.shortestSide;

    // 1. Sade, temiz zemin (Koyu modda tam olarak Antigravity / Emergent sıcak koyu kahve-antrasit #141312)
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF141312) : const Color(0xFFF8F9FB);

    canvas.drawRect(rect, basePaint);

    // 2. Çok renkliden az renkliye geçiş: Düşük opaklıkta, göz yormayan,
    // sadece alt yarıda hafifçe süzülen yumuşak pastel tonlar
    final blobs = <_FloatingPastelOrb>[
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFD6B88D) // Koyu modda sıcak kehribar/kahve ışıltısı
            : const Color(0xFF93C5FD), // Aydınlık modda çok yumuşak mavi
        baseX: 0.20,
        swayAmp: 0.08,
        progress: (progress + 0.00) % 1.0,
        swayPhase: t,
        radiusFactor: 0.30,
        maxAlpha: isDark ? 0.06 : 0.24,
      ),
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFC99E8C) // Sıcak bronz-gül
            : const Color(0xFFF9A8D4), // Çok yumuşak pembe
        baseX: 0.46,
        swayAmp: 0.08,
        progress: (progress + 0.25) % 1.0,
        swayPhase: t + 1.4,
        radiusFactor: 0.28,
        maxAlpha: isDark ? 0.05 : 0.20,
      ),
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFB8A390) // Sıcak taş/taupe
            : const Color(0xFFC4B5FD), // Çok yumuşak lavanta/mor
        baseX: 0.72,
        swayAmp: 0.08,
        progress: (progress + 0.50) % 1.0,
        swayPhase: t + 2.8,
        radiusFactor: 0.30,
        maxAlpha: isDark ? 0.05 : 0.22,
      ),
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFA8B5A0) // Sıcak zeytin/pastel yeşil
            : const Color(0xFFA7F3D0), // Çok yumuşak açık pastel yeşil
        baseX: 0.84,
        swayAmp: 0.08,
        progress: (progress + 0.75) % 1.0,
        swayPhase: t + 4.1,
        radiusFactor: 0.28,
        maxAlpha: isDark ? 0.05 : 0.22,
      ),
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFD4B499)
            : const Color(0xFFBAE6FD),
        baseX: 0.34,
        swayAmp: 0.07,
        progress: (progress + 0.38) % 1.0,
        swayPhase: -t + 2.0,
        radiusFactor: 0.26,
        maxAlpha: isDark ? 0.04 : 0.18,
      ),
      _FloatingPastelOrb.rising(
        color: isDark
            ? const Color(0xFFC2A892)
            : const Color(0xFFDDD6FE),
        baseX: 0.62,
        swayAmp: 0.07,
        progress: (progress + 0.82) % 1.0,
        swayPhase: -t + 4.4,
        radiusFactor: 0.26,
        maxAlpha: isDark ? 0.04 : 0.18,
      ),
    ];

    canvas.saveLayer(rect, Paint());

    for (final orb in blobs) {
      final center = Offset(size.width * orb.cx, size.height * orb.cy);
      final radius = shortSide * orb.radiusFactor;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: orb.alpha),
            orb.color.withValues(alpha: orb.alpha * 0.55),
            orb.color.withValues(alpha: orb.alpha * 0.18),
            orb.color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }

    // Ekranın yarısından (0.50) yukarıya hiçbir rengin geçmemesi için yumuşak maske
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x88FFFFFF),
          Color(0xFFFFFFFF),
        ],
        stops: [0.0, 0.50, 0.60, 0.74],
      ).createShader(rect);

    canvas.drawRect(rect, maskPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BottomFloatingPastelPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _FloatingPastelOrb {
  final Color color;
  final double cx;
  final double cy;
  final double radiusFactor;
  final double alpha;

  const _FloatingPastelOrb({
    required this.color,
    required this.cx,
    required this.cy,
    required this.radiusFactor,
    required this.alpha,
  });

  factory _FloatingPastelOrb.rising({
    required Color color,
    required double baseX,
    required double swayAmp,
    required double progress,
    required double swayPhase,
    required double radiusFactor,
    required double maxAlpha,
  }) {
    final cy = 1.04 - (progress * 0.46);
    final cx = baseX + math.sin(swayPhase) * swayAmp;
    final envelope = math.sin(progress * math.pi).clamp(0.0, 1.0);
    return _FloatingPastelOrb(
      color: color,
      cx: cx,
      cy: cy,
      radiusFactor: radiusFactor,
      alpha: maxAlpha * envelope,
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

/// Sadeleştirilmiş (Az Renkli) Kontrast & Yüzey Sistemi
class AppGlass {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF5F3F0) : const Color(0xFF1E293B);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFD6D1C9) : const Color(0xFF475569);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF9C958C) : const Color(0xFF64748B);

  static Color accentBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFFE7E2DA) : const Color(0xFF334155);

  static Color systemBlue(BuildContext context) =>
      isDark(context) ? const Color(0xFFA8A096) : const Color(0xFF334155);

  static Color subtleSurface(BuildContext context) => isDark(context)
      ? const Color(0xFF2B2825).withValues(alpha: 0.85)
      : const Color(0xFF0F172A).withValues(alpha: 0.04);

  static Color dividerColor(BuildContext context) => isDark(context)
      ? const Color(0xFFFFF8F0).withValues(alpha: 0.08)
      : const Color(0xFF0F172A).withValues(alpha: 0.06);
}

/// 3B görünümü ve aşırı parlak kenar çizgileri kaldırılmış,
/// düz, dingin ve yumuşak mat-cam kart bileşeni.
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
    this.borderRadius = 24.0,
    this.tone = GlassCardTone.standard,
    this.customBorderColor,
    this.blurSigma = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final isUrgentRed = tone == GlassCardTone.urgentRed;

    // Koyu modda zeminden (#121110) belirgin biçimde ayrılan daha açık sıcak koyu kart yüzeyi (#211F1D)
    final Color bgColor = isDark
        ? const Color(0xFF211F1D).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.74);

    final Gradient? cardGradient = isUrgentRed
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF261F1E).withValues(alpha: 0.94),
                    const Color(0xFF3B1E22).withValues(alpha: 0.90),
                    const Color(0xFF521E26).withValues(alpha: 0.86),
                  ]
                : [
                    const Color(0xFFFFF5F6).withValues(alpha: 0.94),
                    const Color(0xFFFFE0E5).withValues(alpha: 0.88),
                    const Color(0xFFFECDD6).withValues(alpha: 0.84),
                  ],
            stops: const [0.0, 0.48, 1.0],
          )
        : null;

    // 3B kabartma hissi vermeyen çok ince, neredeyse belirsiz mat sınır
    final Color borderColor = customBorderColor ??
        (isUrgentRed
            ? (isDark
                ? const Color(0xFFE11D48).withValues(alpha: 0.26)
                : const Color(0xFFE11D48).withValues(alpha: 0.16))
            : (isDark
                ? const Color(0xFFFFF8F0).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.05)));

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: cardGradient == null ? bgColor : null,
              gradient: cardGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: 0.7,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Sade Kapsül Buton Bileşeni
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
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);

    final Color bgColor;
    final Color fgColor;

    if (isSecondaryGlass) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFF0F172A).withValues(alpha: 0.05);
      fgColor = AppGlass.textPrimary(context);
    } else if (isDestructive) {
      bgColor = const Color(0xFFE11D48);
      fgColor = Colors.white;
    } else if (color != null) {
      bgColor = color!;
      fgColor = Colors.white;
    } else {
      bgColor = isDark ? Colors.white : const Color(0xFF1E293B);
      fgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.75,
      onPressed: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 12.5,
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

/// Arka planı bulanıklaştıran (blur) ve temaya uyum sağlayan modal açılır menü yardımcısı
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final isDark = AppGlass.isDark(context);
  return showCupertinoModalPopup<T>(
    context: context,
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.45)
        : const Color(0xFF0F172A).withValues(alpha: 0.16),
    builder: (ctx) => Material(
      type: MaterialType.transparency,
      child: builder(ctx),
    ),
  );
}

/// Alt Pencere (Temaya Uyarlı Modal Bottom Sheet)
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
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1D1B).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFFFFF8F0).withValues(alpha: 0.10)
                    : const Color(0xFF0F172A).withValues(alpha: 0.08),
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
