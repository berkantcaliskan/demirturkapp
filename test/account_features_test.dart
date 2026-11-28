import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senet_takip/services/app_state.dart';
import 'package:senet_takip/services/account_pdf_export.dart';
import 'package:senet_takip/screens/auth/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Paid deposit and 50 future instalments produce exact purchase balances and a PDF', () async {
    final state = AppState();
    addTearDown(state.dispose);
    state.replaceBackendCustomerData(
      customerRow: {
        'id': 'example',
        'full_name': 'Örnek Müşteri',
        'phone': '+905555555555',
        'contract_status': 'approved',
        'contract_number': 'ÖRNEK-2026',
        'project_name': 'Yenişehir',
        'unit_label': 'A Blok · Daire 12',
        'down_payment_amount': 1500000,
        'is_demo': true,
      },
      noteRows: [
        for (var i = 1; i <= 50; i++)
          {
            'id': 'note-$i',
            'customer_id': 'example',
            'note_number': 'ÖRNEK-$i',
            'installment_index': i,
            'total_installments': 50,
            'amount': 35000,
            'status': 'pending',
            'due_date': DateTime(2026, 12 + i - 1, 28).toIso8601String(),
          },
      ],
      bankRows: [],
    );
    expect(state.getCustomerTotalAmount('example'), 3250000);
    expect(state.getCustomerPaidAmount('example'), 1500000);
    expect(state.getCustomerRemainingAmount('example'), 1750000);
    expect(state.customerNotes.length, 50);
    final bytes = await buildAccountPdf(state, {
      'name': 'Örnek Müşteri',
      'phone': '+905555555555',
      'email': 'ornek@example.invalid',
    });
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    if (Platform.environment['SAVE_ACCOUNT_PDF'] == '1') {
      final file = File('../work/storefront-preview/Ornek-Hesap-Verileri.pdf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
  });
  testWidgets(
    'Registration requires name and immutable email while email login enables passwords',
    (tester) async {
      final state = AppState();
      addTearDown(state.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: AuthScreen(appState: state)));
      await tester.enterText(
        find.byType(TextFormField).first,
        'person@example.invalid',
      );
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, 'LongPassword42');
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        'LongPassword42',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
