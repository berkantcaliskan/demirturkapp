import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import 'iban_and_statement_sheets.dart';

class CustomerNotesScreen extends StatelessWidget {
  final AppState appState;

  const CustomerNotesScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final customer = appState.currentCustomer;
    final notes = appState.customerNotes;
    final total = appState.getCustomerTotalAmount(customer.id);
    final paid = appState.getCustomerPaidAmount(customer.id);
    final remaining = appState.getCustomerRemainingAmount(customer.id);

    final paidCount = notes.where((n) => n.status == NoteStatus.paid).length;
    final remainingCount = notes.length - paidCount;

    final unpaidNotes =
        notes.where((n) => n.status != NoteStatus.paid).toList();
    final nextDueNote = unpaidNotes.isNotEmpty ? unpaidNotes.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // 1. Üst Özet: Kalan Ödeme büyük, altında toplam miktar, kalan senet ve detaylar küçük
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KALAN ÖDEME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  height: 1.1,
                  color: AppGlass.textMuted(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatCurrency(remaining),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  height: 1.1,
                  color: AppGlass.textPrimary(context),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SmallSummaryDetail(
                      label: 'Toplam',
                      value: formatCompactCurrency(total),
                    ),
                  ),
                  Expanded(
                    child: _SmallSummaryDetail(
                      label: 'Ödenen',
                      value: formatCompactCurrency(paid),
                    ),
                  ),
                  Expanded(
                    child: _SmallSummaryDetail(
                      label: 'Kalan Senet',
                      value: '$remainingCount / ${notes.length}',
                    ),
                  ),
                  Expanded(
                    child: _SmallSummaryDetail(
                      label: 'Sıradaki Vade',
                      value: nextDueNote != null
                          ? formatShortDate(nextDueNote.dueDate)
                          : '-',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Ödeme Bilgileri (Kuruma) Kartı — Şimdilik tıklandığında açılmaz
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppGlass.subtleSurface(context),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  CupertinoIcons.building_2_fill,
                  size: 16,
                  color: AppGlass.textPrimary(context),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Ödeme Bilgileri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: AppGlass.textSecondary(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Tek Kart Uzun Senetler
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Senetler',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                  Text(
                    '$paidCount / ${notes.length} Taksit',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppGlass.textMuted(context),
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
              ...notes.map((note) {
                final Color statusDotColor;
                switch (note.status) {
                  case NoteStatus.paid:
                    statusDotColor = const Color(0xFF30D158);
                    break;
                  case NoteStatus.overdue:
                    statusDotColor = const Color(0xFFE11D48);
                    break;
                  case NoteStatus.verifying:
                    statusDotColor = const Color(0xFFF59E0B);
                    break;
                  case NoteStatus.pending:
                    statusDotColor = AppGlass.textMuted(context);
                    break;
                }

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusDotColor,
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
                                          color:
                                              AppGlass.textSecondary(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Padding(
                                  padding: const EdgeInsets.only(left: 11),
                                  child: Text(
                                    note.status.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: note.status == NoteStatus.overdue
                                          ? const Color(0xFFE11D48)
                                          : AppGlass.textMuted(context),
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
                              ],
                            ),
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
      ],
    );
  }
}

class _SmallSummaryDetail extends StatelessWidget {
  final String label;
  final String value;

  const _SmallSummaryDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppGlass.textMuted(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppGlass.textPrimary(context),
          ),
        ),
      ],
    );
  }
}
