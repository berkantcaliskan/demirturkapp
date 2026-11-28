import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'app_state.dart';
import '../models/app_models.dart';

Future<Uint8List> buildAccountPdf(
  AppState state,
  Map<String, dynamic> account,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
  );
  final c = state.currentCustomer;
  final hasContract =
      c.id.isNotEmpty && c.contractNo.isNotEmpty && !c.contractPending;
  final rows = <List<String>>[
    ['Adı ve Soyadı', account['name']?.toString() ?? c.name],
    ['E-posta', account['email']?.toString() ?? c.email],
    ['Telefon', account['phone']?.toString() ?? c.phone],
    if (hasContract) ...[
      ['Sözleşme numarası', c.contractNo],
      ['Satın alınan proje', c.projectTitle],
      ['Bağımsız bölüm', c.unitLabel ?? ''],
      ['Adres', c.address],
      [
        'Toplam sözleşme bedeli',
        formatCurrency(state.getCustomerTotalAmount(c.id)),
      ],
      ['Ödenen toplam', formatCurrency(state.getCustomerPaidAmount(c.id))],
      ['Ödenmiş peşinat', formatCurrency(c.downPaymentAmount)],
      ['Kalan borç', formatCurrency(state.getCustomerRemainingAmount(c.id))],
      [
        'Kalan taksit sayısı',
        state.customerNotes
            .where((n) => n.remainingAmount > 0 && n.installmentIndex > 0)
            .length
            .toString(),
      ],
      ['Sözleşme belgesi', c.contractDocumentName ?? 'Henüz yüklenmedi'],
    ],
  ];
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 20),
        child: pw.Text(
          'DEMİRTÜRK MOBİL — Hesap Verileri',
          style: pw.TextStyle(font: bold, fontSize: 18),
        ),
      ),
      footer: (context) => pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      build: (_) => [
        pw.Text('Oluşturulma: ${formatDate(DateTime.now())}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          data: rows,
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
          },
          cellAlignment: pw.Alignment.centerLeft,
          headerCount: 0,
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.all(7),
        ),
        if (!hasContract)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('Hesabınıza henüz bir sözleşme atanmamış.'),
          ),
        if (hasContract && state.customerNotes.isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text('Ödeme planı', style: pw.TextStyle(font: bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Senet', 'Vade', 'Tutar', 'Ödenen', 'Kalan'],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            data: state.customerNotes
                .map(
                  (n) => [
                    n.senetNo,
                    formatDate(n.dueDate),
                    formatCurrency(n.amount),
                    formatCurrency(n.paidAmount),
                    formatCurrency(n.remainingAmount),
                  ],
                )
                .toList(),
          ),
        ],
        pw.SizedBox(height: 22),
        pw.Text(
          'Bu döküm yalnızca bu hesaba eşleştirilmiş satın alım ve ödeme bilgilerini içerir. Genel proje tanıtımı içermez. İmzalı sözleşmenin asıl dosyasına uygulamadaki Sözleşmelerim bölümünden ulaşabilirsiniz.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> shareAccountPdf(
  AppState state,
  Map<String, dynamic> account,
) async {
  final bytes = await buildAccountPdf(state, account);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'Demirturk-Hesap-Verileri.pdf',
  );
}
