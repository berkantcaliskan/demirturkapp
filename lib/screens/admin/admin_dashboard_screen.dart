import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import '../customer/customer_support_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AppState appState;
  final int activeTabIndex;

  const AdminDashboardScreen({
    super.key,
    required this.appState,
    required this.activeTabIndex,
  });

  @override
  Widget build(BuildContext context) {
    switch (activeTabIndex) {
      case 0:
        return _buildApprovalsAndOverviewTab(context);
      case 1:
        return _buildAllNotesTab(context);
      case 2:
        return _buildCustomersTab(context);
      case 3:
        return _buildMessagesTab(context);
      default:
        return _buildApprovalsAndOverviewTab(context);
    }
  }

  Widget _buildApprovalsAndOverviewTab(BuildContext context) {
    final verifyingNotes = appState.allNotes
        .where((n) => n.status == NoteStatus.verifying)
        .toList();
    final overdueNotes = appState.allNotes
        .where((n) => n.status == NoteStatus.overdue)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Company KPI Grid (iOS Frosted Glass Hero Card)
        GlassCard(
          tone: GlassCardTone.hero,
          borderRadius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    color: Color(0xFF64D2FF),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ŞİRKET GENEL SENET & TAHSİLAT ÖZETİ',
                      style: TextStyle(
                        color: AppGlass.textSecondary(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      context,
                      'Toplam Portföy',
                      formatCurrency(appState.companyTotalReceivables),
                      const Color(0xFF64D2FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiBox(
                      context,
                      'Tahsil Edilen',
                      formatCurrency(appState.companyTotalCollected),
                      const Color(0xFF30D158),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      context,
                      'Onay Bekleyen Dekont',
                      formatCurrency(appState.companyTotalVerifying),
                      const Color(0xFFFFD60A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiBox(
                      context,
                      'Gecikmiş Alacak',
                      formatCurrency(appState.companyTotalOverdue),
                      const Color(0xFFFF453A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: Onay Bekleyen Dekontlar
        Row(
          children: [
            const Icon(
              CupertinoIcons.timelapse,
              color: Color(0xFFFFD60A),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Onay Bekleyen Dekontlar (${verifyingNotes.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (verifyingNotes.isEmpty)
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: Color(0xFF30D158),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'İncelenmeyi bekleyen dekont bulunmuyor.',
                    style: TextStyle(color: AppGlass.textSecondary(context)),
                  ),
                ),
              ],
            ),
          )
        else
          ...verifyingNotes.map((note) {
            final customer = appState.getCustomerById(note.customerId);
            return GlassCard(
              tone: GlassCardTone.warningAmber,
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(note.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${note.senetNo} (${note.installmentIndex}/${note.totalInstallments}. Senet) • Vade: ${formatShortDate(note.dueDate)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppGlass.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 0.6,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.paperclip,
                              size: 16,
                              color: Color(0xFF64D2FF),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dosya: ${note.receiptFileName ?? "dekont.pdf"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: Color(0xFF64D2FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (note.paymentMethod != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Yöntem: ${note.paymentMethod}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                        ],
                        if (note.receiptNote != null &&
                            note.receiptNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Müşteri Notu: "${note.receiptNote}"',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppGlass.textMuted(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: IosGlassButton(
                          isSecondaryGlass: true,
                          icon: CupertinoIcons.xmark_circle,
                          label: 'Reddet',
                          onTap: () =>
                              _showRejectDialog(context, note.id, note.senetNo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IosGlassButton(
                          color: const Color(0xFF30D158),
                          icon: CupertinoIcons.checkmark_alt_circle_fill,
                          label: 'Ödemeyi Onayla',
                          onTap: () {
                            appState.approveNotePayment(note.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF059669),
                                content: Text(
                                  '${note.senetNo} ödemesi onaylandı ve müşteriye bildirim gönderildi!',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 18),

        // Section: Geciken Senetler & Hatırlatma
        Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF453A),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vadesi Geçmiş Senetler (${overdueNotes.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (overdueNotes.isEmpty)
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Text(
              'Gecikmiş senet bulunmamaktadır.',
              style: TextStyle(color: AppGlass.textSecondary(context)),
            ),
          )
        else
          ...overdueNotes.map((note) {
            final customer = appState.getCustomerById(note.customerId);
            return GlassCard(
              tone: GlassCardTone.urgentRed,
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(note.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFFFF6961),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${note.senetNo} • Vade: ${formatShortDate(note.dueDate)} • Tel: ${customer.phone}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppGlass.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: IosGlassButton(
                          isSecondaryGlass: true,
                          icon: CupertinoIcons.bell_fill,
                          label: 'Hatırlatma Gönder',
                          onTap: () {
                            appState.sendPaymentReminder(note);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${customer.name} adlı müşteriye ödeme hatırlatma bildirimi gönderildi.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IosGlassButton(
                          icon: CupertinoIcons.checkmark_alt_circle_fill,
                          label: 'Tahsil Edildi',
                          onTap: () {
                            appState.approveNotePayment(
                              note.id,
                              customMethod: 'Şirket Veznesi / Elden Tahsilat',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${note.senetNo} elden tahsil edildi olarak işaretlendi.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
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

  Widget _buildAllNotesTab(BuildContext context) {
    final notes = appState.allNotes.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        GlassCard(
          tone: GlassCardTone.infoBlue,
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yeni Senet / Taksit Planı Oluştur',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Müşteriye tek senet veya sıralı aylık taksit planı tanımlayın',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppGlass.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IosGlassButton(
                onTap: () => _showCreateInstallmentSheet(context),
                icon: CupertinoIcons.add,
                label: 'Senet Ekle',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tüm Müşteri Senetleri (${notes.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ...notes.map((note) {
          final customer = appState.getCustomerById(note.customerId);
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            borderRadius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: note.status.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: note.status.color.withValues(alpha: 0.45),
                      width: 0.7,
                    ),
                  ),
                  child: Icon(
                    note.status.icon,
                    color: note.status.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${customer.name} • ${note.senetNo}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vade: ${formatShortDate(note.dueDate)} (${note.installmentIndex}/${note.totalInstallments}. Taksit)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppGlass.textMuted(context),
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
                        fontSize: 14.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (note.status != NoteStatus.paid)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {
                          appState.approveNotePayment(note.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${note.senetNo} ödendi olarak işaretlendi.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0A84FF).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF64D2FF)
                                  .withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),
                          child: const Text(
                            'Tahsil Et ✓',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64D2FF),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Ödendi',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: note.status.color,
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

  Widget _buildCustomersTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kayıtlı Müşteriler (${appState.customers.length})',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            IosGlassButton(
              onTap: () => _showAddCustomerSheet(context),
              color: const Color(0xFFFF9F0A),
              icon: CupertinoIcons.person_add_solid,
              label: 'Yeni Müşteri Ekle',
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              borderRadius: 18,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...appState.customers.map((c) {
          final total = appState.getCustomerTotalAmount(c.id);
          final paid = appState.getCustomerPaidAmount(c.id);
          final remaining = appState.getCustomerRemainingAmount(c.id);

          return GlassCard(
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: 22,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
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
                        c.name.substring(0, 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Sözleşme: ${c.contractNo} • Tel: ${c.phone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppGlass.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      onPressed: () {
                        appState.selectCustomer(c.id);
                        appState.setRole(UserRole.customer);
                      },
                      child: const Row(
                        children: [
                          Text(
                            'Müşteri Ekranı',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64D2FF),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 13,
                            color: Color(0xFF64D2FF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child:
                      Divider(height: 1, color: AppGlass.dividerColor(context)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniBalance(
                        context,
                        'Toplam Senet',
                        formatCurrency(total),
                        Colors.white,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniBalance(
                        context,
                        'Tahsil Edilen',
                        formatCurrency(paid),
                        const Color(0xFF30D158),
                      ),
                    ),
                    Expanded(
                      child: _buildMiniBalance(
                        context,
                        'Kalan Bakiye',
                        formatCurrency(remaining),
                        const Color(0xFFFF453A),
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

  Widget _buildMessagesTab(BuildContext context) {
    final tickets = appState.allTickets;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text(
          'Müşteri Destek & İletişim Talepleri (${tickets.length})',
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...tickets.map((ticket) {
          final customer = appState.getCustomerById(ticket.customerId);
          final lastMsg =
              ticket.messages.isNotEmpty ? ticket.messages.last : null;

          return GlassCard(
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: 20,
            child: CupertinoButton(
              padding: const EdgeInsets.all(16),
              pressedOpacity: 0.7,
              onPressed: () => showTicketChatModal(
                context,
                appState: appState,
                ticketId: ticket.id,
                isAdminMode: true,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF64D2FF),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ticket.isResolved
                                    ? const Color(0xFF30D158)
                                        .withValues(alpha: 0.22)
                                    : const Color(0xFFFF9F0A)
                                        .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ticket.isResolved
                                      ? const Color(0xFF30D158)
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFFFFD60A)
                                          .withValues(alpha: 0.5),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                ticket.isResolved
                                    ? 'Çözüldü'
                                    : 'Yanıt Bekliyor',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ticket.isResolved
                                      ? const Color(0xFF30D158)
                                      : const Color(0xFFFFD60A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                        if (lastMsg != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${lastMsg.senderName}: ${lastMsg.text}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                        ],
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
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKpiBox(
    BuildContext context,
    String label,
    String value,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppGlass.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppGlass.textMuted(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBalance(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppGlass.textMuted(context)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showRejectDialog(BuildContext context, String noteId, String senetNo) {
    final reasonCtrl = TextEditingController(
      text: 'Dekont tutarı veya alıcı hesap bilgisi eşleşmedi.',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: IosGlassSheet(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$senetNo Dekontunu Reddet',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: IosGlassButton(
                          isSecondaryGlass: true,
                          label: 'Vazgeç',
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IosGlassButton(
                          isDestructive: true,
                          icon: CupertinoIcons.xmark_circle_fill,
                          label: 'Reddet',
                          onTap: () {
                            appState.rejectNotePayment(
                              noteId,
                              reasonCtrl.text.trim(),
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateInstallmentSheet(BuildContext context) {
    String selectedCustomerId = appState.customers.first.id;
    final amountCtrl = TextEditingController(text: '30000');
    final descCtrl = TextEditingController(
      text: 'Yeni Sözleşme Senet Planı',
    );
    int installmentCount = 6;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: IosGlassSheet(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Yeni Senet / Taksit Planı Tanımla',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Müşteri Seçin',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: appState.customers.map((c) {
                          final active = c.id == selectedCustomerId;
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () =>
                                setModalState(() => selectedCustomerId = c.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF0A84FF)
                                        .withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Her Senet Tutarı (₺)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Senet Adedi (Ay)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [1, 3, 6, 12, 18, 24].map((cnt) {
                          final active = cnt == installmentCount;
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () =>
                                setModalState(() => installmentCount = cnt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF0A84FF)
                                        .withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                '$cnt Ay',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sözleşme / Senet Açıklaması',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: descCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: IosGlassButton(
                          icon: CupertinoIcons.checkmark_alt_circle_fill,
                          label: 'Senet Planını Oluştur',
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          onTap: () {
                            final amount =
                                double.tryParse(amountCtrl.text.trim()) ??
                                    25000.0;
                            appState.createInstallmentPlan(
                              customerId: selectedCustomerId,
                              monthlyAmount: amount,
                              installmentCount: installmentCount,
                              firstDueDate: DateTime(2026, 12, 15),
                              descriptionPrefix: descCtrl.text.trim().isEmpty
                                  ? 'Senet Ödemesi'
                                  : descCtrl.text.trim(),
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF059669),
                                content: Text(
                                  '$installmentCount adet yeni senet başarıyla oluşturuldu!',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final tcCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+90 532 ');
    final contractCtrl = TextEditingController(
      text: 'DMR-2026-0${appState.customers.length + 401}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: IosGlassSheet(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Yeni Müşteri Cari Kaydı Oluştur',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSheetInput(
                    controller: nameCtrl,
                    placeholder: 'Müşteri Adı Soyadı / Firma Unvanı',
                  ),
                  const SizedBox(height: 10),
                  _buildSheetInput(
                    controller: tcCtrl,
                    placeholder: 'TC Kimlik No / Vergi No',
                  ),
                  const SizedBox(height: 10),
                  _buildSheetInput(
                    controller: phoneCtrl,
                    placeholder: 'Telefon Numarası',
                  ),
                  const SizedBox(height: 10),
                  _buildSheetInput(
                    controller: contractCtrl,
                    placeholder: 'Sözleşme Numarası',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: IosGlassButton(
                      icon: CupertinoIcons.person_add_solid,
                      label: 'Müşteriyi Kaydet',
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onTap: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        appState.addCustomer(
                          name: nameCtrl.text.trim(),
                          tcOrTaxNo: tcCtrl.text.trim().isEmpty
                              ? '11111111110'
                              : tcCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: 'musteri@eposta.com',
                          address: 'Karasu / Sakarya',
                          contractNo: contractCtrl.text.trim(),
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetInput({
    required TextEditingController controller,
    required String placeholder,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      placeholderStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 13.5,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 0.7,
        ),
      ),
    );
  }
}
