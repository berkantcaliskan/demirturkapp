import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/portal_repository.dart';
import '../services/user_facing_error.dart';
import 'website_blurred_background.dart';

class CustomerFinanceCard extends StatefulWidget {
  const CustomerFinanceCard({
    super.key,
    required this.appState,
    required this.customerId,
    this.repository,
    this.compact = false,
  });
  final AppState appState;
  final String customerId;
  final PortalRepository? repository;
  final bool compact;
  @override
  State<CustomerFinanceCard> createState() => _CustomerFinanceCardState();
}

class _CustomerFinanceCardState extends State<CustomerFinanceCard> {
  bool _refreshing = false;
  int _shownPayments = 5;
  Future<void> _refresh() async {
    final repository = widget.repository;
    if (repository == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await repository.syncCustomerFinance(widget.customerId);
      final rows = await repository.loadFinanceSnapshots();
      final notes = await repository.loadNotes();
      if (!mounted) return;
      widget.appState.replaceBackendFinances(rows);
      widget.appState.replaceBackendNotes(notes);
      widget.appState.setFinanceError(widget.customerId, null);
    } catch (error) {
      if (mounted)
        widget.appState.setFinanceError(
          widget.customerId,
          userFacingError(
            error,
            fallback: 'Ödeme bilgileri yenilenemedi. Son doğrulanmış bilgiler gösteriliyor.',
          ),
        );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.appState,
    builder: (context, _) {
      final finance = widget.appState.financeFor(widget.customerId);
      final error = widget.appState.financeErrorFor(widget.customerId);
      if (finance == null && error == null) return const SizedBox.shrink();
      final primary = AppGlass.textPrimary(context),
          secondary = AppGlass.textSecondary(context);
      final stale =
          finance != null &&
          DateTime.now().difference(finance.importedAt).inMinutes > 5;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: primary,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Ödeme planı',
                        style: TextStyle(
                          color: primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.repository != null)
                      IconButton(
                        tooltip: 'Ödemeleri yenile',
                        onPressed: _refreshing ? null : _refresh,
                        icon: _refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 20),
                      ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: primary,
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (finance != null) ...[
                  Text(
                    '${stale ? 'Son doğrulanmış bilgiler' : 'Güncellendi'} · ${formatShortDate(finance.asOf.toLocal())} ${finance.asOf.toLocal().hour.toString().padLeft(2, '0')}:${finance.asOf.toLocal().minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: secondary, fontSize: 11),
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in <(String, double)>[
                            ('Planlanan peşinat', finance.plannedDownPayment),
                            ('Planlanan kapora', finance.plannedDeposit),
                            ('Tahsil edilen peşinat / kapora', finance.prepaid),
                            if (finance.refunded > 0)
                              ('İade edilen', finance.refunded),
                          ])
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$1,
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatCurrency(item.$2),
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final (index, contract) in finance.contracts.indexed)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        textColor: primary,
                        collapsedTextColor: primary,
                        iconColor: secondary,
                        collapsedIconColor: secondary,
                        title: Text(
                          'Ödeme planı ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${(contract['notes'] as List).length} senet · ${formatCurrency((contract['totalCents'] as int) / 100)}',
                          style: TextStyle(color: secondary, fontSize: 11),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${contract['creditor']}\nDüzenleme: ${contract['issuedOn']} · ${contract['issuePlace']}',
                                style: TextStyle(
                                  color: secondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          for (final (paymentIndex, planned)
                              in (contract['prepayments'] as List? ?? const [])
                                  .indexed)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Planlanan peşinat ${paymentIndex + 1}: ${formatCurrency((planned['amountCents'] as int) / 100)} · ${planned['dueDate'] ?? 'Tarih belirtilmedi'}',
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (finance.payments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tahsilat geçmişi',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final payment in finance.payments.take(
                        _shownPayments,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payment['paidDate'] as String,
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      [
                                            payment['method'],
                                            payment['receiptNumber'],
                                          ]
                                          .whereType<String>()
                                          .where((s) => s.isNotEmpty)
                                          .join(' · '),
                                      style: TextStyle(
                                        color: secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatCurrency(
                                  (payment['amountCents'] as int) / 100,
                                ),
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_shownPayments < finance.payments.length)
                        TextButton(
                          onPressed: () => setState(() => _shownPayments += 5),
                          child: const Text('Daha fazla tahsilat'),
                        ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
