import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/models/app_models.dart';
import 'package:senet_takip/models/customer_finance.dart';
import 'package:senet_takip/services/app_state.dart';
import 'package:senet_takip/services/portal_repository.dart';
import 'package:senet_takip/screens/admin/admin_dashboard_screen.dart';
import 'package:senet_takip/widgets/customer_finance_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancePreviewRepository extends PortalRepository {
  FinancePreviewRepository()
    : super(
        SupabaseClient(
          'https://example.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int syncCalls = 0, paymentWrites = 0;
  @override
  Future<void> syncCustomerFinance(String customerId) async {
    syncCalls++;
  }

  @override
  Future<List<Map<String, dynamic>>> loadFinanceSnapshots() async => [
    financeRow(),
  ];
  @override
  Future<List<Map<String, dynamic>>> loadNotes() async => [];
  @override
  Future<void> reviewPaymentSubmission({
    required String noteId,
    required bool approved,
    String? rejectionReason,
    String? paymentMethod,
  }) async {
    paymentWrites++;
  }
}

Map<String, dynamic> financeRow() => {
  'customer_id': 'customer',
  'imported_at': DateTime.now().toUtc().toIso8601String(),
  'snapshot': {
    'schemaVersion': 1,
    'currency': 'TRY',
    'asOf': '2026-11-27T12:00:00Z',
    'contracts': [
      {
        'sourceId': 'plan',
        'totalCents': 200000,
        'paidCents': 110000,
        'remainingCents': 90000,
        'plannedDepositCents': 10000,
        'plannedDownPaymentCents': 50000,
        'prepaidCents': 60000,
        'refundedCents': 0,
        'creditor': 'Test company',
        'issuedOn': '2026-11-01',
        'issuePlace': 'Karasu',
        'notes': [
          {'sourceId': '1'},
          {'sourceId': '2'},
        ],
        'payments': [
          {
            'id': 'receipt',
            'amountCents': 50000,
            'paidDate': '2026-11-27',
            'method': 'Havale',
            'receiptNumber': 'TEST-1',
          },
        ],
      },
    ],
  },
};
void main() {
  test('Customer and company totals include prepayments without double counting imported notes', () {
    final state = AppState();
    state.replaceBackendNotes([
      {
        'id': 'n1',
        'customer_id': 'customer',
        'note_number': '1',
        'installment_index': 1,
        'total_installments': 2,
        'amount': 700,
        'due_date': '2026-12-31',
        'status': 'pending',
        'crm_plan_id': 'plan',
        'crm_paid_amount': 500,
      },
    ]);
    state.replaceBackendFinances([financeRow()]);
    expect(state.getCustomerTotalAmount('customer'), 2000);
    expect(state.getCustomerPaidAmount('customer'), 1100);
    expect(state.getCustomerRemainingAmount('customer'), 900);
    expect(state.companyTotalReceivables, 2000);
    expect(state.companyTotalCollected, 1100);
    expect(state.allNotes.single.remainingAmount, 200);
    expect(state.allNotes.single.isPartiallyPaid, isTrue);
    state.clearSessionData();
    expect(state.financeFor('customer'), isNull);
  });
  test('Invalid balances fail validation before replacing a previous financial snapshot', () {
    final row = financeRow();
    ((row['snapshot'] as Map)['contracts'] as List).first['paidCents'] = 1;
    expect(() => CustomerFinance.fromRow(row), throwsFormatException);
  });
  test('Legacy payment totals and copy behavior remain compatible', () {
    final note = PromissoryNote(
      id: 'legacy',
      customerId: 'customer',
      senetNo: '1',
      installmentIndex: 1,
      totalInstallments: 1,
      amount: 100,
      dueDate: constDate,
      status: NoteStatus.paid,
      description: '',
    );
    expect(note.paidAmount, 100);
    expect(note.remainingAmount, 0);
    expect(note.copyWith().paidAmount, 100);
  });
  for (final crm in [true, false]) {
    testWidgets(
      'Finance review ${crm ? 'refreshes CRM' : 'keeps legacy approval'} without changing the other flow',
      (tester) async {
        final state = AppState()..setRole(UserRole.accounting);
        addTearDown(state.dispose);
        state.replaceBackendNotes([
          {
            'id': 'review',
            'customer_id': 'customer',
            'note_number': 'TEST-REVIEW',
            'installment_index': 1,
            'total_installments': 1,
            'amount': 700,
            'due_date': '2027-12-31',
            'status': 'verifying',
            if (crm) 'crm_plan_id': 'plan',
            if (crm) 'crm_paid_amount': 100,
          },
        ]);
        final repository = FinancePreviewRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminDashboardScreen(
                appState: state,
                activeTabIndex: 0,
                repository: repository,
                onPreviewCustomer: (_) {},
              ),
            ),
          ),
        );
        final action = find
            .text(crm ? 'CRM’den yenile' : 'Ödemeyi Onayla')
            .first;
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(repository.syncCalls, crm ? 1 : 0);
        expect(repository.paymentWrites, crm ? 0 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets('Finance card fits narrow screens in ${brightness.name} mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState()..replaceBackendFinances([financeRow()]);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CustomerFinanceCard(
                appState: state,
                customerId: 'customer',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tahsilat geçmişi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

final constDate = DateTime(2026, 12, 31);
