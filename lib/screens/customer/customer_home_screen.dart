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

  @override
  Widget build(BuildContext context) {
    final customer = appState.currentCustomer;
    final notes = appState.customerNotes;
    final total = appState.getCustomerTotalAmount(customer.id);
    final paid = appState.getCustomerPaidAmount(customer.id);
    final remaining = appState.getCustomerRemainingAmount(customer.id);
    final overdue = appState.getCustomerOverdueAmount(customer.id);
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    final overdueNotes =
        notes.where((n) => n.status == NoteStatus.overdue).toList();
    final nextPendingNotes =
        notes.where((n) => n.status == NoteStatus.pending).toList();
    final urgentNote = overdueNotes.isNotEmpty
        ? overdueNotes.first
        : (nextPendingNotes.isNotEmpty ? nextPendingNotes.first : null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // iOS Frosted Glass Customer Header & Action-Sheet Switcher
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                    color: Colors.white.withValues(alpha: 0.40),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  customer.name.substring(0, 1),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  pressedOpacity: 0.65,
                  onPressed: () => _showIosCustomerPicker(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hoş Geldiniz,',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppGlass.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${customer.name} (${customer.contractNo})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: AppGlass.textPrimary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            CupertinoIcons.chevron_down_circle_fill,
                            size: 16,
                            color: AppGlass.accentBlue(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                pressedOpacity: 0.65,
                onPressed: () => showNotificationsSheet(context, appState),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppGlass.subtleSurface(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        CupertinoIcons.bell_fill,
                        size: 18,
                        color: Colors.white,
                      ),
                      if (appState.unreadNotificationCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF453A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.2,
                              ),
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
        const SizedBox(height: 14),

        // iOS Apple Card / Wallet Style Frosted Glass Financial Summary Card
        GlassCard(
          tone: GlassCardTone.hero,
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'KALAN TOPLAM SENET BORCU',
                      style: TextStyle(
                        color: AppGlass.accentBlue(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      customer.contractNo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              // iOS Frosted Glass Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF30D158),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Ödeme İlerlemesi: %${(progress * 100).round()}',
                      style: const TextStyle(
                        color: Color(0xFF30D158),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${notes.where((n) => n.status == NoteStatus.paid).length} / ${notes.length} Senet Ödendi',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: AppGlass.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  color: AppGlass.dividerColor(context),
                  height: 1,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      context,
                      'Toplam Tutar',
                      formatCurrency(total),
                      CupertinoIcons.creditcard_fill,
                      const Color(0xFF64D2FF),
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      context,
                      'Ödenen Tutar',
                      formatCurrency(paid),
                      CupertinoIcons.checkmark_alt_circle_fill,
                      const Color(0xFF30D158),
                    ),
                  ),
                  if (overdue > 0)
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Gecikmiş',
                        formatCurrency(overdue),
                        CupertinoIcons.exclamationmark_circle_fill,
                        const Color(0xFFFF453A),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // iOS Control Center Style Frosted Glass Quick Action Grid
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.building_2_fill,
                label: 'Şirket IBAN',
                sublabel: 'Kopyala & EFT',
                color: const Color(0xFF0A84FF),
                onTap: () => showIbanSheet(context, appState),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.arrow_up_doc_fill,
                label: 'Dekont Yükle',
                sublabel: 'Ödeme Bildir',
                color: const Color(0xFF30D158),
                onTap: () => showUploadReceiptSheet(context, appState),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.doc_richtext,
                label: 'Ekstre İndir',
                sublabel: 'Senet Planı',
                color: const Color(0xFFBF5AF2),
                onTap: () => showAccountStatementDialog(context, appState),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: CupertinoIcons.chat_bubble_2_fill,
                label: 'Canlı Destek',
                sublabel: 'Mesaj Gönder',
                color: const Color(0xFFFF9F0A),
                onTap: () => onNavigateTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Urgent / Next Payment Card (iOS Notification Summary Glass Style)
        if (urgentNote != null) ...[
          GlassCard(
            tone: urgentNote.status == NoteStatus.overdue
                ? GlassCardTone.urgentRed
                : GlassCardTone.infoBlue,
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      urgentNote.status == NoteStatus.overdue
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.calendar_badge_plus,
                      color: urgentNote.status == NoteStatus.overdue
                          ? const Color(0xFFFF453A)
                          : const Color(0xFF64D2FF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        urgentNote.status == NoteStatus.overdue
                            ? 'Vadesi Geçmiş Senet Ödemeniz Bulunuyor'
                            : 'Sıradaki Yaklaşan Senet Ödemeniz',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        urgentNote.senetNo,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vade Tarihi: ${formatDate(urgentNote.dueDate)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppGlass.textSecondary(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(urgentNote.amount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IosGlassButton(
                      onTap: () => showUploadReceiptSheet(
                        context,
                        appState,
                        preselectedNote: urgentNote,
                      ),
                      isDestructive: urgentNote.status == NoteStatus.overdue,
                      icon: CupertinoIcons.arrow_up_doc_fill,
                      label: 'Ödeme Bildir',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Section Header: Senet Planı Özeti
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Senet & Taksit Takvimi',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => onNavigateTab(1),
              child: const Row(
                children: [
                  Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64D2FF),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 14,
                    color: Color(0xFF64D2FF),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...notes.take(4).map((note) {
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            borderRadius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: note.status.bgColor,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: note.status.color.withValues(alpha: 0.45),
                      width: 0.7,
                    ),
                  ),
                  child: Icon(
                    note.status.icon,
                    color: note.status.color,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              note.senetNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '(${note.installmentIndex}/${note.totalInstallments}. Taksit)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppGlass.textMuted(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Vade: ${formatDate(note.dueDate)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppGlass.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(note.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: note.status.bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: note.status.color.withValues(alpha: 0.45),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        note.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: note.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showIosCustomerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Müşteri Hesabı Seçin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
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
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A84FF).withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF64D2FF)
                                  : Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sözleşme: ${c.contractNo} • ${c.address}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Color(0xFF64D2FF),
                                  size: 20,
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

  Widget _buildMetricItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppGlass.textMuted(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: AppGlass.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
