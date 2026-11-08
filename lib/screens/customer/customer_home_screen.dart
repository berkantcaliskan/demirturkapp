import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import 'iban_and_statement_sheets.dart';

class CustomerHomeScreen extends StatelessWidget {
  final AppState appState;
  final ValueChanged<int> onNavigateTab;

  const CustomerHomeScreen({
    super.key,
    required this.appState,
    required this.onNavigateTab,
  });

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Günaydın';
    } else if (hour >= 12 && hour < 16) {
      return 'Merhaba';
    } else if (hour >= 16 && hour < 22) {
      return 'İyi akşamlar';
    } else {
      return 'İyi geceler';
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = appState.currentCustomer;
    final notes = appState.customerNotes;
    final total = appState.getCustomerTotalAmount(customer.id);
    final paid = appState.getCustomerPaidAmount(customer.id);
    final remaining = appState.getCustomerRemainingAmount(customer.id);
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final paidCount = notes.where((n) => n.status == NoteStatus.paid).length;
    final isDark = AppGlass.isDark(context);

    final overdueNotes =
        notes.where((n) => n.status == NoteStatus.overdue).toList();
    final nextPendingNotes =
        notes.where((n) => n.status == NoteStatus.pending).toList();
    final urgentNote = overdueNotes.isNotEmpty
        ? overdueNotes.first
        : (nextPendingNotes.isNotEmpty
            ? nextPendingNotes.first
            : (notes.isNotEmpty ? notes.first : null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: [
        // 1. Müşteri Başlığı & Seçici (Karşısındaki 4 menü kaldırıldı)
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          pressedOpacity: 0.7,
          alignment: Alignment.centerLeft,
          onPressed: () => _showIosCustomerPicker(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '${_timeBasedGreeting()} ${customer.firstName}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: AppGlass.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // 2. HERO KART: Müşterinin Satın Aldığı Ev & Alt Metrik Barı (3B kenarlıksız, az renkli)
        _PurchasedHouseHeroCard(
          customer: customer,
          remaining: remaining,
          paid: paid,
          total: total,
          paidCount: paidCount,
          totalNotes: notes.length,
          isDark: isDark,
          onPayTap: () => showUploadReceiptSheet(
            context,
            appState,
            preselectedNote: urgentNote,
          ),
          onDetailsTap: () => onNavigateTab(1),
        ),
        const SizedBox(height: 14),

        // 3. Dalga Grafiği Kartı: Performans (Gecikmeye göre düşen performans eğrisi)
        _PaymentWaveAnalyticsCard(
          paidCount: paidCount,
          totalNotes: notes.length,
          overdueCount: overdueNotes.length,
        ),
        const SizedBox(height: 14),

        // 4. Üçüncü Kart: Gecikmiş / Ödenmemiş Senet Kartı (Ödenmemiş senet yoksa yeşil Harika görünümü)
        _NextInstallmentSpotlightCard(
          customer: customer,
          overdueNote: overdueNotes.isNotEmpty ? overdueNotes.first : null,
          paidCount: paidCount,
          totalNotes: notes.length,
          progress: progress,
          onUploadTap: () {
            if (overdueNotes.isNotEmpty) {
              showUploadReceiptSheet(
                context,
                appState,
                preselectedNote: overdueNotes.first,
              );
            } else {
              onNavigateTab(1);
            }
          },
          onIbanTap: () => showIbanSheet(context, appState),
        ),
        const SizedBox(height: 14),

        // 5. Birleşik Senet & Taksit Tablo Kartı
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Bu Dönemdeki Senet & Taksitleriniz',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppGlass.textPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () =>
                        showAccountStatementDialog(context, appState),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ekstre',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppGlass.textPrimary(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 11,
                            color: AppGlass.textSecondary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Konut & Senet',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppGlass.textMuted(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Vade Tarihi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppGlass.textMuted(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Tutar',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppGlass.textMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: AppGlass.dividerColor(context),
              ),
              const SizedBox(height: 10),

              ...notes.take(3).map((note) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (note.status != NoteStatus.paid) {
                        showUploadReceiptSheet(
                          context,
                          appState,
                          preselectedNote: note,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SizedBox(
                              width: 50,
                              height: 40,
                              child: Image.asset(
                                customer.projectImageAsset,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${customer.projectTitle} • ${note.senetNo}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: AppGlass.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${note.installmentIndex}/${note.totalInstallments}. Elden Senet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppGlass.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: note.status == NoteStatus.overdue
                                        ? const Color(0xFFE11D48)
                                        : AppGlass.textMuted(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    formatShortDate(note.dueDate),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppGlass.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCompactCurrency(note.amount),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppGlass.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 40,
                                  height: 10,
                                  child: CustomPaint(
                                    painter: _MiniSparklinePainter(
                                      color: AppGlass.textMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  onPressed: () => onNavigateTab(1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppGlass.textSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 13,
                        color: AppGlass.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showIosCustomerPicker(BuildContext context) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = AppGlass.isDark(ctx);
        return IosGlassSheet(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFF0F172A).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Müşteri & Konut Hesabı Seçin',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppGlass.textPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...appState.customers.map((c) {
                    final isSelected = c.id == appState.selectedCustomerId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          appState.selectCustomer(c.id);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : const Color(0xFF0F172A)
                                        .withValues(alpha: 0.08))
                                : AppGlass.subtleSurface(ctx),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.38)
                                      : const Color(0xFF0F172A)
                                          .withValues(alpha: 0.22))
                                  : AppGlass.dividerColor(ctx),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 46,
                                  height: 40,
                                  child: Image.asset(
                                    c.projectImageAsset,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: TextStyle(
                                        color: AppGlass.textPrimary(ctx),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.projectTitle} (${c.unitSubtitle}) • ${c.contractNo}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppGlass.textMuted(ctx),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: AppGlass.textPrimary(ctx),
                                  size: 19,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Müşterinin Satın Aldığı Ev Hero Kartı (3B kenarlıksız, az renkli, dingince sadeleştirilmiş)
class _PurchasedHouseHeroCard extends StatelessWidget {
  final Customer customer;
  final double remaining;
  final double paid;
  final double total;
  final int paidCount;
  final int totalNotes;
  final bool isDark;
  final VoidCallback onPayTap;
  final VoidCallback onDetailsTap;

  const _PurchasedHouseHeroCard({
    required this.customer,
    required this.remaining,
    required this.paid,
    required this.total,
    required this.paidCount,
    required this.totalNotes,
    required this.isDark,
    required this.onPayTap,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    const double topOverhang = 24.0;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF64748B);

    // Sol kenarda blurlu ve yumuşak geçiş sağlayan alt görsel katmanı
    Widget buildSoftBlurredTransitionImage() {
      return ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x59FFFFFF),
              Color(0xD9FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            stops: [
              0.00,
              0.34,
              0.41,
              0.48,
              0.55,
              1.00,
            ],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.68,
            heightFactor: 1.0,
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Image.asset(
                  customer.projectImageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Sağda net bina ve çatı çıkıntısını koruyan ana görsel katmanı
    Widget buildProjectImage() {
      return ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x38FFFFFF),
              Color(0xA6FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            stops: [
              0.00,
              0.39,
              0.45,
              0.51,
              0.56,
              1.00,
            ],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.68,
            heightFactor: 1.0,
            child: ClipRect(
              child: Image.asset(
                customer.projectImageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ana Kart Gövdesi (Gökyüzü ve sağ/sol/alt sınırlar kartın içinde kalır)
        Padding(
          padding: const EdgeInsets.only(top: topOverhang),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF211F1D) : Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                children: [
                  // 1a. Sol geçişte yumuşak blurlu erime katmanı
                  Positioned(
                    top: -topOverhang,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: buildSoftBlurredTransitionImage(),
                  ),

                  // 1b. Sağ tarafta net ev görseli (blurlu katman üzerine yumuşakça oturur)
                  Positioned(
                    top: -topOverhang,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: buildProjectImage(),
                  ),

                  // İnce kart kenarlığı
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFFFF8F0).withValues(alpha: 0.08)
                                : const Color(0xFF0F172A)
                                    .withValues(alpha: 0.05),
                            width: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Ön Yüz İçerik
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.projectTitle,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          customer.unitSubtitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            letterSpacing: -0.2,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 54),

                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          pressedOpacity: 0.8,
                          onPressed: onPayTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Ödeme Bildir',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Alt Metrik Barı (Sağa doğru hafif saydamlaşan, okunaklı beyaz/buzlu cam bar)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 10, 11),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: isDark
                                      ? [
                                          const Color(0xFF211F1D)
                                              .withValues(alpha: 0.90),
                                          const Color(0xFF211F1D)
                                              .withValues(alpha: 0.80),
                                          const Color(0xFF211F1D)
                                              .withValues(alpha: 0.66),
                                          const Color(0xFF211F1D)
                                              .withValues(alpha: 0.52),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.95),
                                          Colors.white.withValues(alpha: 0.89),
                                          Colors.white.withValues(alpha: 0.76),
                                          Colors.white.withValues(alpha: 0.64),
                                        ],
                                  stops: const [0.0, 0.36, 0.68, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFF0F172A)
                                          .withValues(alpha: 0.06),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _HeroFrostedMetricItem(
                                      value: formatCompactCurrency(remaining),
                                      label: 'Kalan',
                                      icon: CupertinoIcons.creditcard,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _HeroFrostedMetricItem(
                                      value: formatCompactCurrency(paid),
                                      label: 'Ödenen',
                                      icon: CupertinoIcons.checkmark_alt,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _HeroFrostedMetricItem(
                                      value: formatCompactCurrency(total),
                                      label: 'Toplam',
                                      icon: CupertinoIcons.house,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _HeroFrostedMetricItem(
                                      value: '$paidCount/$totalNotes',
                                      label: 'Senet',
                                      icon: CupertinoIcons.doc_text,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    onPressed: onDetailsTap,
                                    child: Icon(
                                      CupertinoIcons.chevron_forward,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF1E293B),
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Üstten Kart Dışına Taşan Proje Binası Katmanı (Gökyüzü kırpılmış, sadece bina çatısı üstten taşar)
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: _BuildingTopOverhangClipper(
                assetPath: customer.projectImageAsset,
                topOverhang: topOverhang,
              ),
              child: buildProjectImage(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Proje binasının yalnızca çatı/üst silüetini kartın üst sınırından dışarı taşırır;
/// gökyüzünü ve sağ/sol/alt kenarları dışarı taşırmaz.
class _BuildingTopOverhangClipper extends CustomClipper<Path> {
  final String assetPath;
  final double topOverhang;

  const _BuildingTopOverhangClipper({
    required this.assetPath,
    required this.topOverhang,
  });

  @override
  Path getClip(Size size) {
    // Sağ %68'lik görsel kutusunun dış Stack içindeki koordinatları
    final double boxWidth = size.width * 0.68;
    final double boxLeft = size.width - boxWidth;
    final double boxHeight = size.height;

    // 1672x941 kaynak görselin BoxFit.cover + Alignment.center ile yerleşimi
    const double srcW = 1672.0;
    const double srcH = 941.0;
    final double scaleX = boxWidth / srcW;
    final double scaleY = boxHeight / srcH;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double renderedW = srcW * scale;
    final double renderedH = srcH * scale;
    final double offsetX = boxLeft + (boxWidth - renderedW) / 2.0;
    final double offsetY = (boxHeight - renderedH) / 2.0;

    Offset pt(double u, double v) {
      return Offset(offsetX + u * renderedW, offsetY + v * renderedH);
    }

    // Bina çatı silüeti noktaları (gökyüzünü dışarıda bırakır, hafif 0.002 iç pay ile mavi saçak kalmaz)
    final List<Offset> roofPoints;
    if (assetPath.contains('asel')) {
      roofPoints = [
        pt(0.000, 0.436),
        pt(0.144, 0.353),
        pt(0.329, 0.025),
        pt(0.359, 0.028),
        pt(0.434, 0.125),
        pt(0.523, 0.129),
        pt(0.574, 0.346),
        pt(1.000, 0.480),
      ];
    } else if (assetPath.contains('almina')) {
      roofPoints = [
        pt(0.000, 0.266),
        pt(0.125, 0.260),
        pt(0.595, 0.326),
        pt(0.802, 0.272),
        pt(1.000, 0.306),
      ];
    } else {
      // yenisehirforweb.jpeg (Yeni Şehir 3. Etap)
      roofPoints = [
        pt(0.000, 0.397),
        pt(0.191, 0.261),
        pt(0.546, 0.012),
        pt(0.824, 0.246),
        pt(0.818, 0.285),
        pt(0.906, 0.360),
        pt(0.935, 0.342),
        pt(1.000, 0.393),
      ];
    }

    final Path buildingPath = Path()..moveTo(roofPoints.first.dx, roofPoints.first.dy);
    for (int i = 1; i < roofPoints.length; i++) {
      buildingPath.lineTo(roofPoints[i].dx, roofPoints[i].dy);
    }
    // Sadece kartın üst sınır çizgisine (topOverhang + 2px) kadar olan üst taşma bölgesini kapat
    final double seamBottom = topOverhang + 2.0;
    buildingPath
      ..lineTo(offsetX + renderedW, seamBottom)
      ..lineTo(offsetX, seamBottom)
      ..close();

    // Sağdan ve soldan kartın üst köşe kavislerinin dışına taşmaması için yatay sınır
    final Path allowedTopZone = Path()
      ..addRect(
        Rect.fromLTRB(
          26.0,
          0.0,
          size.width - 26.0,
          seamBottom,
        ),
      );

    return Path.combine(PathOperation.intersect, buildingPath, allowedTopZone);
  }

  @override
  bool shouldReclip(covariant _BuildingTopOverhangClipper oldClipper) {
    return oldClipper.assetPath != assetPath ||
        oldClipper.topOverhang != topOverhang;
  }
}

class _HeroFrostedMetricItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;

  const _HeroFrostedMetricItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF475569);
    final badgeBg = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFF0F172A).withValues(alpha: 0.09);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                icon,
                size: 8.5,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// İkili Eğri Analitik Kartı (Gecikmeye göre düşen ödeme performansı grafiği)
class _PaymentWaveAnalyticsCard extends StatelessWidget {
  final int paidCount;
  final int totalNotes;
  final int overdueCount;

  const _PaymentWaveAnalyticsCard({
    required this.paidCount,
    required this.totalNotes,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    // Normalde %100 olan performans, gecikmiş senet oldukça düşer (ileride yönetici ayarlarına bağlanacak)
    final int performanceScore =
        (100 - (overdueCount * 18)).clamp(20, 100);
    final isDark = AppGlass.isDark(context);

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Performans',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppGlass.textPrimary(context),
                ),
              ),
              const Spacer(),
              Text(
                '$paidCount / $totalNotes Taksit',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppGlass.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _DualWaveChartPainter(
                highlightText: '%$performanceScore',
                hasDelay: overdueCount > 0,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Ağu', 'Eyl', 'Eki', 'Kas'].map((m) {
                return Text(
                  m,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppGlass.textMuted(context),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DualWaveChartPainter extends CustomPainter {
  final String highlightText;
  final bool hasDelay;
  final bool isDark;

  const _DualWaveChartPainter({
    required this.highlightText,
    this.hasDelay = true,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 26.0;
    const topPad = 16.0;
    const bottomPad = 8.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFF0F172A).withValues(alpha: 0.05)
      ..strokeWidth = 0.8;

    final labels = ['100', '75', '50', '25'];
    for (int i = 0; i < labels.length; i++) {
      final y = topPad + (chartH / (labels.length - 1)) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.45)
                : const Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final peakX = leftPad + chartW * 0.82;
    final peakY = topPad + chartH * 0.24;

    final barPath = Path()
      ..moveTo(peakX - 11, topPad + chartH)
      ..lineTo(peakX - 15, peakY)
      ..arcToPoint(
        Offset(peakX + 15, peakY),
        radius: const Radius.circular(15),
      )
      ..lineTo(peakX + 11, topPad + chartH)
      ..close();

    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.02),
              ]
            : [
                const Color(0xFF0F172A).withValues(alpha: 0.08),
                const Color(0xFF0F172A).withValues(alpha: 0.01),
              ],
      ).createShader(Rect.fromLTWH(peakX - 16, peakY, 32, chartH));
    canvas.drawPath(barPath, barPaint);

    // 1. İkincil yumuşak gri eğri
    final firstPath = Path()
      ..moveTo(leftPad + chartW * 0.02, topPad + chartH * 0.88)
      ..cubicTo(
        leftPad + chartW * 0.14,
        topPad + chartH * 0.28,
        leftPad + chartW * 0.24,
        topPad + chartH * 0.58,
        leftPad + chartW * 0.38,
        topPad + chartH * 0.15,
      )
      ..cubicTo(
        leftPad + chartW * 0.50,
        topPad + chartH * 0.02,
        leftPad + chartW * 0.58,
        topPad + chartH * 0.72,
        leftPad + chartW * 0.70,
        topPad + chartH * 0.52,
      )
      ..cubicTo(
        leftPad + chartW * 0.80,
        topPad + chartH * 0.35,
        leftPad + chartW * 0.90,
        topPad + chartH * 0.25,
        leftPad + chartW * 0.98,
        topPad + chartH * 0.58,
      );

    final firstCurvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.30)
          : const Color(0xFF94A3B8).withValues(alpha: 0.55);
    canvas.drawPath(firstPath, firstCurvePaint);

    // 2. Birincil antrasit / beyaz eğri
    final secondPath = Path()
      ..moveTo(leftPad + chartW * 0.02, topPad + chartH * 0.88)
      ..cubicTo(
        leftPad + chartW * 0.16,
        topPad + chartH * 0.72,
        leftPad + chartW * 0.26,
        topPad + chartH * 0.32,
        leftPad + chartW * 0.36,
        topPad + chartH * 0.52,
      )
      ..cubicTo(
        leftPad + chartW * 0.46,
        topPad + chartH * 0.88,
        leftPad + chartW * 0.56,
        topPad + chartH * 0.82,
        leftPad + chartW * 0.68,
        topPad + chartH * 0.38,
      )
      ..cubicTo(
        leftPad + chartW * 0.75,
        topPad + chartH * 0.18,
        leftPad + chartW * 0.86,
        topPad + chartH * 0.18,
        leftPad + chartW * 0.98,
        topPad + chartH * 0.68,
      );

    final primaryLineColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

    final secondCurvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = primaryLineColor;
    canvas.drawPath(secondPath, secondCurvePaint);

    canvas.drawCircle(
      Offset(peakX, peakY + 4),
      4.0,
      Paint()..color = primaryLineColor,
    );

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(peakX, topPad + 2),
        width: 40,
        height: 19,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isDark ? Colors.white : const Color(0xFF1E293B),
    );

    final badgeTp = TextPainter(
      text: TextSpan(
        text: highlightText,
        style: TextStyle(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeTp.paint(
      canvas,
      Offset(peakX - badgeTp.width / 2, topPad + 2 - badgeTp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DualWaveChartPainter oldDelegate) {
    return oldDelegate.highlightText != highlightText ||
        oldDelegate.hasDelay != hasDelay ||
        oldDelegate.isDark != isDark;
  }
}

/// Üçüncü Kart: Gecikmiş Senet / Ödenmemiş Senet Yoksa Yeşil "Harika" Kartı
class _NextInstallmentSpotlightCard extends StatelessWidget {
  final Customer customer;
  final PromissoryNote? overdueNote;
  final int paidCount;
  final int totalNotes;
  final double progress;
  final VoidCallback onUploadTap;
  final VoidCallback onIbanTap;

  const _NextInstallmentSpotlightCard({
    required this.customer,
    required this.overdueNote,
    required this.paidCount,
    required this.totalNotes,
    required this.progress,
    required this.onUploadTap,
    required this.onIbanTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final note = overdueNote;
    final hasOverdue = note != null;
    final greenAccent =
        isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);

    return GlassCard(
      borderRadius: 24,
      tone: hasOverdue ? GlassCardTone.urgentRed : GlassCardTone.successGreen,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: hasOverdue
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gecikmiş Senet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppGlass.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 16,
                            child: CustomPaint(
                              painter: _MiniSparklinePainter(
                                color: AppGlass.textSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${note.installmentIndex}/${note.totalInstallments} Taksit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatCurrency(note.amount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(context),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              CupertinoIcons.calendar,
                              size: 13,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vade: ${formatDate(note.dueDate)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppGlass.textMuted(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 16,
                            child: CustomPaint(
                              painter: _MiniSparklinePainter(
                                color: greenAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$paidCount/$totalNotes Taksit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Harika',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: greenAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ödenmemiş senediniz yok',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppGlass.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: onUploadTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppGlass.subtleSurface(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 78,
                        width: double.infinity,
                        child: Image.asset(
                          customer.projectImageAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customer.projectTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasOverdue ? 'Dekont Yükle →' : 'Ödemelerim →',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: hasOverdue
                            ? AppGlass.textSecondary(context)
                            : greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;

  const _MiniSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.10,
        size.width * 0.35,
        size.height * 0.95,
        size.width * 0.55,
        size.height * 0.25,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.0,
        size.width * 0.85,
        size.height * 0.85,
        size.width,
        size.height * 0.45,
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
