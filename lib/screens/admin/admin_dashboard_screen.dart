import '../../services/user_facing_error.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/portal_repository.dart';
import '../../services/upload_policy.dart';
import '../../utils/turkish_phone_input_formatter.dart';
import '../../widgets/contract_document_button.dart';
import '../../widgets/crm_finance_link_button.dart';
import '../../widgets/contract_document_upload_button.dart';
import 'admin_support_inbox_screen.dart';
import '../../widgets/website_blurred_background.dart';
import '../customer/customer_support_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AppState appState;
  final int activeTabIndex;
  final PortalRepository? repository;
  final ValueChanged<Customer> onPreviewCustomer;

  const AdminDashboardScreen({
    super.key,
    required this.appState,
    required this.activeTabIndex,
    required this.onPreviewCustomer,
    this.repository,
  });

  Future<void> _refreshCrmFinance(BuildContext context, PromissoryNote note) async {
    final source = repository;
    if (source == null) return;
    try {
      await source.syncCustomerFinance(note.customerId);
      appState.replaceBackendFinances(await source.loadFinanceSnapshots());
      appState.replaceBackendNotes(await source.loadNotes());
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('CRM ödeme bilgileri yenilendi. Tahsilatları e-Demirtürk’te kaydedebilirsiniz.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFacingError(error, fallback: 'Ödeme bilgileri yenilenemedi.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (appState.currentRole.isSalesAdvisor) {
      return switch (activeTabIndex) {
        0 => _buildCustomersTab(context),
        1 => _buildCustomersTab(context, processOnly: true),
        2 =>
          repository == null
              ? _buildMessagesTab(context)
              : AdminSupportInboxScreen(repository: repository!),
        3 =>
          repository == null
              ? _buildMessagesTab(context)
              : AdminSupportInboxScreen(
                  repository: repository!,
                  closedOnly: true,
                ),
        _ => _buildCustomersTab(context),
      };
    }
    switch (activeTabIndex) {
      case 0:
        return _buildApprovalsAndOverviewTab(context);
      case 1:
        return _buildAllNotesTab(context);
      case 2:
        return _buildCustomersTab(context);
      case 3:
        return repository == null
            ? _buildMessagesTab(context)
            : AdminSupportInboxScreen(repository: repository!);
      case 4:
        return repository == null
            ? _buildMessagesTab(context)
            : AdminSupportInboxScreen(
                repository: repository!,
                closedOnly: true,
              );
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppGlass.textPrimary(context),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: -0.3,
                            color: AppGlass.textPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(note.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: -0.3,
                          color: AppGlass.textPrimary(context),
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
                        if (note.receiptObjectPath != null &&
                            repository != null)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            alignment: Alignment.centerLeft,
                            onPressed: () async {
                              try {
                                final uri = await repository!
                                    .getPaymentReceiptUrl(
                                      note.receiptObjectPath!,
                                    );
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(userFacingError(error, fallback: 'Dekont açılamadı. Tekrar deneyin.')),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.paperclip,
                                  size: 16,
                                  color: Color(0xFF64D2FF),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Dekontu aç • ${note.receiptFileName ?? 'dosya'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: Color(0xFF64D2FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
                          label: note.crmPlanId == null ? 'Ödemeyi Onayla' : 'CRM’den yenile',
                          onTap: () async {
                            if (note.crmPlanId != null) { await _refreshCrmFinance(context, note); return; }
                            if (repository == null) {
                              appState.approveNotePayment(note.id);
                            } else {
                              try {
                                await repository!.reviewPaymentSubmission(
                                  noteId: note.id,
                                  approved: true,
                                  paymentMethod: note.paymentMethod,
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(userFacingError(error, fallback: 'Onay kaydedilemedi. Tekrar deneyin.')),
                                  ),
                                );
                                return;
                              }
                            }
                            if (!context.mounted) return;
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppGlass.textPrimary(context),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            color: AppGlass.textPrimary(context),
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
                          onTap: () async {
                            if (repository == null) {
                              appState.sendPaymentReminder(note);
                            } else {
                              try {
                                await repository!.sendPaymentReminder(
                                  customerId: note.customerId,
                                  noteNumber: note.senetNo,
                                  dueDate: formatShortDate(note.dueDate),
                                  amountText: formatCurrency(note.amount),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userFacingError(error, fallback: 'Hatırlatma gönderilemedi. Tekrar deneyin.'),
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            if (!context.mounted) return;
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
                          label: note.crmPlanId == null ? 'Tahsil Edildi' : 'CRM’den yenile',
                          onTap: () async {
                            if (note.crmPlanId != null) { await _refreshCrmFinance(context, note); return; }
                            if (repository == null) {
                              appState.approveNotePayment(
                                note.id,
                                customMethod: 'Şirket Veznesi / Elden Tahsilat',
                              );
                            } else {
                              try {
                                await repository!.reviewPaymentSubmission(
                                  noteId: note.id,
                                  approved: true,
                                  paymentMethod:
                                      'Şirket Veznesi / Elden Tahsilat',
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userFacingError(error, fallback: 'Tahsilat kaydedilemedi. Tekrar deneyin.'),
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            if (!context.mounted) return;
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
        Text(
          'Tüm Müşteri Senetleri (${notes.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppGlass.textPrimary(context),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          color: AppGlass.textPrimary(context),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (note.status != NoteStatus.paid)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () async {
                          if (note.crmPlanId != null) { await _refreshCrmFinance(context, note); return; }
                          if (repository == null) {
                            appState.approveNotePayment(note.id);
                          } else {
                            try {
                              await repository!.reviewPaymentSubmission(
                                noteId: note.id,
                                approved: true,
                                paymentMethod: note.paymentMethod,
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    userFacingError(error, fallback: 'Güncelleme kaydedilemedi. Tekrar deneyin.'),
                                  ),
                                ),
                              );
                              return;
                            }
                          }
                          if (!context.mounted) return;
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
                            color: const Color(0xFF0A84FF)
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF64D2FF)
                                  .withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            note.crmPlanId == null ? 'Tahsil Et ✓' : 'CRM’den yenile',
                            style: const TextStyle(
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

  Widget _buildCustomersTab(BuildContext context, {bool processOnly = false}) {
    final visibleCustomers = [...appState.customers];
    visibleCustomers.sort((a, b) => a.name.compareTo(b.name));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              processOnly
                  ? 'İnşaat Süreçleri (${appState.customers.length})'
                  : 'Kayıtlı Müşteriler (${appState.customers.length})',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppGlass.textPrimary(context),
              ),
            ),
            if (!processOnly && appState.currentRole.canManageAllCustomers)
              IosGlassButton(
                onTap: () => _showAddCustomerSheet(context),
                color: const Color(0xFFFF9F0A),
                icon: CupertinoIcons.person_add_solid,
                label: 'Yeni Müşteri Ekle',
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                borderRadius: 18,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!processOnly &&
            repository != null &&
            appState.currentRole.canManageAllCustomers) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: IosGlassButton(
              onTap: () => _showAccountLinkReview(context),
              icon: CupertinoIcons.link,
              label: 'Bekleyen hesap eşleşmeleri',
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              borderRadius: 18,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!processOnly && repository != null)
          CustomerFolderManager(
            repository: repository!,
            customers: visibleCustomers,
            onOpenCustomer: onPreviewCustomer,
          ),
        ...visibleCustomers.map((c) {
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
                        c.name.isEmpty ? '?' : c.name.characters.first,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppGlass.textPrimary(context),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.3,
                              color: AppGlass.textPrimary(context),
                            ),
                          ),
                          Text(
                            '${c.contractNo.isEmpty ? 'Sözleşme bekliyor' : 'Sözleşme: ${c.contractNo}'} • Tel: ${c.phone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppGlass.textMuted(context),
                            ),
                          ),
                          if (c.projectName?.isNotEmpty == true)
                            Text(
                              [
                                c.projectName!,
                                if (c.unitLabel?.isNotEmpty == true)
                                  c.unitLabel!,
                              ].join(' · '),
                              style: TextStyle(
                                color: AppGlass.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          if (c.contractPending ||
                              (c.projectStatus?.trim().isNotEmpty ??
                                  false)) ...[
                            const SizedBox(height: 5),
                            Text(
                              c.contractPending
                                  ? 'Sözleşme onay bekliyor'
                                  : c.projectStatus!,
                              style: const TextStyle(
                                color: Color(0xFFFF9F0A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      onPressed: c.isPendingContractRecord
                          ? null
                          : () => onPreviewCustomer(c),
                      child: const Tooltip(
                        message: 'Müşteri ekranına geç',
                        child: Icon(
                            CupertinoIcons.chevron_forward,
                            size: 20,
                            color: Color(0xFF64D2FF),
                          ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: AppGlass.dividerColor(context),
                  ),
                ),
                if (!processOnly &&
                    repository != null &&
                    !c.isPendingContractRecord)
                  CustomerFolderAssignment(
                    repository: repository!,
                    customer: c,
                    onChanged: _refreshCustomers,
                  ),
                if (!processOnly && repository != null) ...[
                  if (c.contractPending &&
                      appState.currentRole.canManageAllCustomers)
                    TextButton.icon(
                      onPressed: () =>
                          _showAccountLinkReview(context, customer: c),
                      icon: const Icon(CupertinoIcons.doc_text_search),
                      label: const Text('Sözleşmeyi gör ve onayla'),
                    )
                  else if (c.contractDocumentPath != null)
                    ContractDocumentButton(
                      repository: repository!,
                      customerId: c.id,
                    ),
                ],
                if (appState.currentRole.canSeePromissoryNotes)
                  if (repository != null && !c.contractPending && !c.isPendingContractRecord)
                    CrmFinanceLinkButton(repository: repository!, customer: c, onChanged: () async {
                      appState.replaceBackendFinances(await repository!.loadFinanceSnapshots());
                      appState.replaceBackendNotes(await repository!.loadNotes());
                      await _refreshCustomers();
                    }),
                if (appState.currentRole.canSeePromissoryNotes)
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniBalance(
                          context,
                          'Toplam Senet',
                          formatCurrency(total),
                          AppGlass.textPrimary(context),
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
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppGlass.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ...tickets.map((ticket) {
          final customer = appState.getCustomerById(ticket.customerId);
          final lastMsg = ticket.messages.isNotEmpty
              ? ticket.messages.last
              : null;

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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                            color: AppGlass.textPrimary(context),
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
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    style: TextStyle(
                      color: AppGlass.textPrimary(context),
                      fontSize: 14,
                    ),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppGlass.dividerColor(context),
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
                          onTap: () async {
                            if (repository == null) {
                              appState.rejectNotePayment(
                                noteId,
                                reasonCtrl.text.trim(),
                              );
                            } else {
                              try {
                                await repository!.reviewPaymentSubmission(
                                  noteId: noteId,
                                  approved: false,
                                  rejectionReason: reasonCtrl.text.trim(),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(userFacingError(error, fallback: 'Ret kaydedilemedi. Tekrar deneyin.')),
                                  ),
                                );
                                return;
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
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

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nameFocus = FocusNode();
    final phoneFocus = FocusNode();
    String projectName = '';
    String unitLabel = '';
    String? advisorId;
    PlatformFile? contractFile;
    Uint8List? contractFileBytes;
    bool saving = false;
    final advisorsFuture = repository?.loadSalesAdvisors();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
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
                    Text(
                      'Yeni Müşteri Cari Kaydı Oluştur',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppGlass.textPrimary(ctx),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSheetInput(
                      ctx,
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      nextFocusNode: phoneFocus,
                      placeholder: 'Müşteri Adı Soyadı / Firma Unvanı',
                    ),
                    const SizedBox(height: 10),
                    _buildSheetInput(
                      ctx,
                      controller: phoneCtrl,
                      focusNode: phoneFocus,
                      placeholder: '5XX XXX XX XX',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [TurkishPhoneInputFormatter()],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Proje adı'),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(120)],
                      onChanged: (value) => projectName = value.trim(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Blok / daire (isteğe bağlı)',
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      onChanged: (value) => unitLabel = value.trim(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(ctx),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppGlass.dividerColor(ctx)),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(13),
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await FilePicker.pickFile(
                                  type: FileType.custom,
                                  allowedExtensions: const [
                                    'pdf',
                                    'doc',
                                    'docx',
                                  ],
                                );
                                if (picked == null) return;
                                final bytes = await UploadPolicy.readFile(picked, UploadPolicy.contractBytes);
                                if (!ctx.mounted || !context.mounted) return;
                                if (bytes.isEmpty) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Dosya okunamadı. Tekrar seçin.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setModalState(() {
                                  contractFile = picked;
                                  contractFileBytes = bytes;
                                });
                              },
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.doc_text,
                              color: Color(0xFFE11D48),
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                contractFile?.name ??
                                    'Sözleşme dosyası seç (PDF / Word)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppGlass.textPrimary(ctx),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (contractFile != null)
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: Color(0xFF34C759),
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: advisorsFuture,
                      builder: (context, snapshot) {
                        final advisors = snapshot.data ?? const [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (advisors.isEmpty) {
                          return const Text(
                            'Önce en az bir Satış Danışmanı hesabı tanımlayın.',
                            style: TextStyle(color: Color(0xFFFF9F0A)),
                          );
                        }
                        advisorId ??= advisors.first['id']?.toString();
                        return StatefulBuilder(
                          builder: (context, setFieldState) {
                            final contractYear = DateTime.now().year;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: advisorId,
                                  decoration: const InputDecoration(
                                    labelText: 'Atanan satış danışmanı',
                                  ),
                                  items: advisors.map((advisor) {
                                    final staffId =
                                        advisor['staff_id']?.toString() ?? '';
                                    return DropdownMenuItem(
                                      value: advisor['id'].toString(),
                                      child: Text(
                                        '${advisor['full_name']} • $staffId',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) =>
                                      setFieldState(() => advisorId = value),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sözleşme numarası otomatik verilir. İlk numara: S/${contractYear}000001; numara sırayla artar.',
                                  style: TextStyle(
                                    color: AppGlass.textSecondary(ctx),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: IosGlassButton(
                        icon: CupertinoIcons.person_add_solid,
                        label: saving ? 'Kaydediliyor…' : 'Müşteriyi Kaydet',
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onTap: () async {
                          if (saving) return;
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final file = contractFile;
                          if (name.isEmpty ||
                              projectName.isEmpty ||
                              !_isValidTurkishPhone(phone) ||
                              advisorId == null ||
                              (file != null && contractFileBytes == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ad, telefon, proje ve danışman zorunludur.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (repository == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sunucu oturumu yok; müşteri Supabase’e gönderilmedi. Yönetici hesabıyla yeniden giriş yapın.',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            setModalState(() => saving = true);
                            final extension = file?.name
                                .split('.')
                                .last
                                .toLowerCase();
                            final contentType = switch (extension) {
                              'pdf' => 'application/pdf',
                              'doc' => 'application/msword',
                              _ => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                            };
                            final savedCustomer = await repository!
                                .createContract(
                                  name: name,
                                  nationalOrTaxId: '',
                                  phone: phone,
                                  assignedAdvisorId: advisorId!,
                                  contractDate: DateTime.now(),
                                  projectName: projectName,
                                  unitLabel: unitLabel,
                                  contractFileName: file?.name,
                                  contractFileBytes: contractFileBytes,
                                  contractContentType: file == null
                                      ? null
                                      : contentType,
                                );
                            if (!ctx.mounted || !context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  'Sözleşme kaydedildi • Numara: ${savedCustomer['contract_number'] ?? 'beklemede'}',
                                ),
                              ),
                            );
                            await _refreshCustomers();
                            return;
                          } catch (error) {
                            if (ctx.mounted) {
                              setModalState(() => saving = false);
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  userFacingError(error, fallback: 'Müşteri Supabase’e gönderilemedi. Tekrar deneyin.'),
                                ),
                              ),
                            );
                            return;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetInput(
    BuildContext context, {
    required TextEditingController controller,
    required String placeholder,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    String? prefixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: nextFocusNode == null
          ? TextInputAction.done
          : TextInputAction.next,
      onSubmitted: (_) {
        if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      placeholder: placeholder,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      prefix: prefixText == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 13, right: 8),
              child: Text(
                prefixText,
                style: TextStyle(
                  color: AppGlass.textPrimary(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      placeholderStyle: TextStyle(
        color: AppGlass.textMuted(context),
        fontSize: 13.5,
      ),
      style: TextStyle(color: AppGlass.textPrimary(context), fontSize: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppGlass.subtleSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppGlass.dividerColor(context), width: 0.7),
      ),
    );
  }

  Future<void> _refreshCustomers() async {
    final currentRepository = repository;
    if (currentRepository == null) return;
    try {
      appState.replaceBackendCustomers(await currentRepository.loadCustomers());
    } catch (error) {
      debugPrint(userFacingError(error, fallback: 'Customers refresh failed. Tekrar deneyin.'));
    }
  }

  Future<void> _showAccountLinkReview(
    BuildContext context, {
    Customer? customer,
  }) async {
    final currentRepository = repository;
    if (currentRepository == null) return;
    await showContractAccountReview(
      context,
      repository: currentRepository,
      customer: customer,
    );
    if (context.mounted) await _refreshCustomers();
  }

  bool _isValidTurkishPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ||
        (digits.length == 11 && digits.startsWith('0'));
  }
}

Future<void> showContractAccountReview(
  BuildContext context, {
  required PortalRepository repository,
  Customer? customer,
  String? delegatedAccountId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _PendingAccountLinksSheet(
    repository: repository,
    customer: customer,
    delegatedAccountId: delegatedAccountId,
  ),
);

class CustomerFolderManager extends StatefulWidget {
  const CustomerFolderManager({
    super.key,
    required this.repository,
    required this.customers,
    required this.onOpenCustomer,
    this.delegatedAccountId,
  });

  final PortalRepository repository;
  final List<Customer> customers;
  final ValueChanged<Customer> onOpenCustomer;
  final String? delegatedAccountId;

  @override
  State<CustomerFolderManager> createState() => _CustomerFolderManagerState();
}

class _CustomerFolderManagerState extends State<CustomerFolderManager> {
  late Future<List<Map<String, dynamic>>> _folders = widget.repository
      .loadCustomerFolders(ownerId: widget.delegatedAccountId);

  void _reload() => setState(
    () => _folders = widget.repository.loadCustomerFolders(
      ownerId: widget.delegatedAccountId,
    ),
  );

  Future<void> _createFolder() async {
    String name = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klasör oluştur'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: const InputDecoration(labelText: 'Klasör adı'),
          onChanged: (value) => name = value.trim(),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (approved != true || name.isEmpty || !mounted) return;
    try {
      final delegatedAccountId = widget.delegatedAccountId;
      if (delegatedAccountId == null) {
        await widget.repository.createCustomerFolder(name);
      } else {
        await widget.repository.performPortalAccountAction(
          delegatedAccountId,
          'create_folder',
          {'name': name},
        );
      }
      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Klasör oluşturulamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _folders,
        builder: (context, snapshot) => GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Klasörler',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Klasör oluştur'),
                  ),
                ],
              ),
              if (snapshot.hasError)
                TextButton(
                  onPressed: _reload,
                  child: const Text('Klasörleri yeniden yükle'),
                )
              else if (!snapshot.hasData)
                const LinearProgressIndicator()
              else
                for (final folder in snapshot.data!)
                  _buildFolder(context, folder),
            ],
          ),
        ),
      );

  Widget _buildFolder(BuildContext context, Map<String, dynamic> folder) {
    final ownerId = folder['created_by'].toString();
    final members = widget.customers
        .where((customer) => customer.foldersByOwner[ownerId] == folder['id'])
        .toList();
    final owner = folder['profiles'] as Map?;
    return ExpansionTile(
      key: PageStorageKey('customer-folder-${folder['id']}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder['name'].toString()),
      subtitle: Text(
        [
          if (ownerId != widget.repository.currentUserId &&
              owner?['full_name'] != null)
            owner!['full_name'].toString(),
          '${members.length} müşteri',
        ].join(' · '),
      ),
      children: [
        if (members.isEmpty)
          const ListTile(dense: true, title: Text('Bu klasör boş.')),
        for (final customer in members)
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(customer.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpenCustomer(customer),
          ),
      ],
    );
  }
}

class CustomerFolderAssignment extends StatefulWidget {
  const CustomerFolderAssignment({
    super.key,
    required this.repository,
    required this.customer,
    required this.onChanged,
    this.delegatedAccountId,
  });

  final PortalRepository repository;
  final Customer customer;
  final Future<void> Function() onChanged;
  final String? delegatedAccountId;

  @override
  State<CustomerFolderAssignment> createState() =>
      _CustomerFolderAssignmentState();
}

class _CustomerFolderAssignmentState extends State<CustomerFolderAssignment> {
  bool _busy = false;
  String? get _ownerId =>
      widget.delegatedAccountId ?? widget.repository.currentUserId;

  Future<void> _chooseFolder() async {
    setState(() => _busy = true);
    try {
      final currentFolderId = widget.customer.foldersByOwner[_ownerId];
      final folders = await widget.repository.loadCustomerFolders(
        ownerId: _ownerId,
      );
      if (!mounted) return;
      final selection = await showDialog<({String? id})>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Kişisel klasör seç'),
          children: [
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Önce bir klasör oluşturun.'),
              ),
            if (currentFolderId != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, (id: null)),
                child: const Text('Klasörden çıkar'),
              ),
            for (final folder in folders)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, (id: folder['id'].toString())),
                child: Text(folder['name'].toString()),
              ),
          ],
        ),
      );
      if (selection == null || !mounted) return;
      final accountId = widget.delegatedAccountId;
      if (accountId == null) {
        await widget.repository.assignCustomerFolder(
          customerId: widget.customer.id,
          folderId: selection.id,
        );
      } else {
        await widget.repository.performPortalAccountAction(
          accountId,
          'assign_folder',
          {'customer_id': widget.customer.id, 'folder_id': selection.id},
        );
      }
      await widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Klasör ataması yapılamadı.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _chooseFolder,
    icon: const Icon(Icons.drive_file_move_outline),
    label: Text(
      widget.customer.foldersByOwner.containsKey(_ownerId)
          ? 'Klasörü değiştir'
          : 'Klasöre ekle',
    ),
  );
}

class _PendingAccountLinksSheet extends StatefulWidget {
  const _PendingAccountLinksSheet({
    required this.repository,
    this.customer,
    this.delegatedAccountId,
  });

  final PortalRepository repository;
  final Customer? customer;
  final String? delegatedAccountId;

  @override
  State<_PendingAccountLinksSheet> createState() =>
      _PendingAccountLinksSheetState();
}

class _PendingAccountLinksSheetState extends State<_PendingAccountLinksSheet> {
  List<Map<String, dynamic>> _matches = const [];
  bool _loading = true;
  String? _error;
  String? _linkingAccountId;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matches = await widget.repository.loadPendingAccountLinks();
      if (!mounted) return;
      setState(() {
        final id = widget.customer?.id;
        _matches = matches.where((match) {
          if (id == null) return true;
          return (match['account'] as Map)['id'] == id ||
              (match['contract'] as Map)['id'] == id;
        }).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error, fallback: 'Hesap eşleşmeleri alınamadı. Tekrar deneyin.');
      });
    }
  }

  Future<void> _link(Map<String, dynamic> match) async {
    final account = match['account'] as Map<String, dynamic>;
    final contract = match['contract'] as Map<String, dynamic>;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı sözleşmeye bağla'),
        content: Text(
          '${match['phone']} numaralı hesabı ${contract['full_name']} adına kayıtlı '
          '${contract['contract_number'] ?? 'bekleyen'} sözleşmesine bağlamak üzeresiniz. '
          'SMS doğrulaması kullanılmadığı için kişinin kimliğini ayrıca kontrol ettiğinizi onaylayın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kimliği kontrol ettim, bağla'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    final accountId = account['id'].toString();
    setState(() => _linkingAccountId = accountId);
    try {
      final delegatedAccountId = widget.delegatedAccountId;
      if (delegatedAccountId != null) {
        await widget.repository.performPortalAccountAction(
          delegatedAccountId,
          'link_contract',
          {
            'contract_id': contract['id'],
            'customer_id': accountId,
            'pending': contract['_pending_contract_record'] == true,
          },
        );
      } else if (contract['_pending_contract_record'] == true) {
        await widget.repository.linkPendingContractAccount(
          pendingContractId: contract['id'].toString(),
          accountCustomerId: accountId,
        );
      } else {
        await widget.repository.linkCustomerAccount(
          contractCustomerId: contract['id'].toString(),
          accountCustomerId: accountId,
        );
      }
      if (!mounted) return;
      setState(
        () => _matches.removeWhere(
          (item) =>
              (item['account'] as Map<String, dynamic>)['id'] == accountId,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesap sözleşmeye bağlandı.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(error, fallback: 'Hesap bağlanamadı. Tekrar deneyin.'))));
    } finally {
      if (mounted) setState(() => _linkingAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.76,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppGlass.dividerColor(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.customer == null
                  ? 'Bekleyen hesap eşleşmeleri'
                  : 'Sözleşmeyi gör ve onayla',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Eşleşme numaraya göre bulunur. Numara tek başına kimlik kanıtı değildir; her hesabı ayrıca kontrol edin.',
              style: TextStyle(
                color: AppGlass.textSecondary(context),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  : _matches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Bağlanmayı bekleyen eşleşme bulunamadı.'),
                          if (widget.customer case final customer?
                              when customer.contractDocumentPath != null)
                            ContractDocumentButton(
                              repository: widget.repository,
                              customerId: customer.id,
                              pending: customer.isPendingContractRecord,
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _matches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final match = _matches[index];
                        final account =
                            match['account'] as Map<String, dynamic>;
                        final contract =
                            match['contract'] as Map<String, dynamic>;
                        final linkedDocument =
                            contract['customer_contract_documents'];
                        final hasDocument =
                            contract['storage_path'] != null ||
                            (linkedDocument is Map &&
                                linkedDocument.isNotEmpty) ||
                            (linkedDocument is List &&
                                linkedDocument.isNotEmpty);
                        final isLinking =
                            _linkingAccountId == account['id'].toString();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppGlass.subtleSurface(context),
                            border: Border.all(
                              color: AppGlass.dividerColor(context),
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${account['full_name']} · ${match['phone']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${contract['full_name']} · ${contract['contract_number']}',
                                style: TextStyle(
                                  color: AppGlass.textSecondary(context),
                                ),
                              ),
                              if (hasDocument)
                                ContractDocumentButton(
                                  repository: widget.repository,
                                  customerId: contract['id'].toString(),
                                  pending:
                                      contract['_pending_contract_record'] ==
                                      true,
                                )
                              else ...[
                                const Text('Sözleşme dosyası eklenmemiş.'),
                                if (contract['_pending_contract_record'] == true)
                                  ContractDocumentUploadButton(
                                    repository: widget.repository,
                                    contractId: contract['id'].toString(),
                                    onSaved: _loadMatches,
                                  ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _linkingAccountId == null && hasDocument
                                      ? () => _link(match)
                                      : null,
                                  icon: isLinking
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(CupertinoIcons.link),
                                  label: const Text(
                                    'Kimliği kontrol ettim, hesabı bağla',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
