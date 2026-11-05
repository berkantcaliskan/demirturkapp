import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';

void showIbanSheet(BuildContext context, AppState appState) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return IosGlassSheet(
        maxHeightFactor: 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF64D2FF).withValues(alpha: 0.45),
                        width: 0.7,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.building_2_fill,
                      color: Color(0xFF64D2FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Şirket Banka & IBAN Bilgileri',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'FAST / EFT / Havale açıklamasına Senet No yazınız',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.16)),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF64D2FF).withValues(alpha: 0.4),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.info_circle_fill,
                          color: Color(0xFF64D2FF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alıcı Unvanı: ${appState.bankAccounts.first.accountHolder}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IosGlassButton(
                          isSecondaryGlass: true,
                          icon: CupertinoIcons.doc_on_doc_fill,
                          label: 'Kopyala',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: appState.bankAccounts.first.accountHolder,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Şirket unvanı kopyalandı!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ...appState.bankAccounts.map((bank) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.7,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: bank.brandColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  bank.bankName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
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
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bank.branchName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bank.iban,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                      fontFamily: 'monospace',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IosGlassButton(
                                  icon: CupertinoIcons.doc_on_doc_fill,
                                  label: 'IBAN Kopyala',
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bank.iban),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${bank.bankName} IBAN kopyalandı!',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showUploadReceiptSheet(
  BuildContext context,
  AppState appState, {
  PromissoryNote? preselectedNote,
}) {
  final unpaidNotes = appState.customerNotes
      .where((n) => n.status != NoteStatus.paid)
      .toList();

  if (unpaidNotes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tüm senetleriniz ödenmiş görünmektedir!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  PromissoryNote selectedNote = preselectedNote != null &&
          unpaidNotes.any((n) => n.id == preselectedNote.id)
      ? unpaidNotes.firstWhere((n) => n.id == preselectedNote.id)
      : unpaidNotes.first;

  String selectedBank = 'HAVALE / EFT (Ziraat Bankası)';
  String selectedFileName =
      'dekont_${selectedNote.senetNo.toLowerCase().replaceAll('-', '_')}.pdf';
  final noteController = TextEditingController();

  final bankOptions = [
    'HAVALE / EFT (Ziraat Bankası)',
    'FAST / Havale (Garanti BBVA)',
    'HAVALE / EFT (Türkiye İş Bankası)',
    'Kredi Kartı / Sanal POS Makbuzu',
    'Şirket veznesine elden ödeme makbuzu',
  ];

  final sampleFiles = [
    'mobil_bankacilik_dekont.pdf',
    'fast_transfer_makbuzu.jpg',
    'eft_onay_belgesi_2026.pdf',
    'vezne_tahsilat_fisi.png',
  ];

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF30D158).withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF30D158)
                                  .withValues(alpha: 0.5),
                              width: 0.7,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_up_doc_fill,
                            color: Color(0xFF30D158),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dekont Yükle & Ödeme Bildir',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Ödeme belgenizi yükleyin, muhasebe onayına iletilsin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => Navigator.pop(ctx),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'İlgili Senet Seçimi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: unpaidNotes.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final note = unpaidNotes[idx];
                          final active = note.id == selectedNote.id;
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () =>
                                setModalState(() => selectedNote = note),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
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
                              child: Center(
                                child: Text(
                                  '${note.senetNo} • ${formatCurrency(note.amount)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ödeme Yöntemi / Banka',
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
                      children: bankOptions.map((b) {
                        final active = b == selectedBank;
                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () =>
                              setModalState(() => selectedBank = b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
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
                              b,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Dekont Dosyası (PDF veya Görsel)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              const Color(0xFF30D158).withValues(alpha: 0.45),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.doc_fill,
                            color: Color(0xFF30D158),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Dekont belgesi eklemeye hazır (245 KB)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IosGlassButton(
                            isSecondaryGlass: true,
                            icon: CupertinoIcons.folder_fill,
                            label: 'Değiştir',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            onTap: () {
                              final nextIdx =
                                  (sampleFiles.indexOf(selectedFileName) + 1) %
                                      sampleFiles.length;
                              setModalState(() {
                                selectedFileName = sampleFiles[nextIdx];
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Açıklama / Not (İsteğe Bağlı)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: noteController,
                      maxLines: 2,
                      placeholder:
                          'Örn: Eşimin hesabından gönderildi, açıklama kısmına senet no yazıldı...',
                      placeholderStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                      ),
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
                        icon: CupertinoIcons.paperplane_fill,
                        color: const Color(0xFF30D158),
                        label:
                            '${formatCurrency(selectedNote.amount)} Ödeme Bildirimini Gönder',
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onTap: () {
                          appState.submitPaymentReceipt(
                            noteId: selectedNote.id,
                            receiptFileName: selectedFileName,
                            paymentMethod: selectedBank,
                            receiptNote: noteController.text.trim().isEmpty
                                ? '$selectedBank üzerinden ödeme yapıldı.'
                                : noteController.text.trim(),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF059669),
                              content: Text(
                                '${selectedNote.senetNo} için dekont yüklendi! Yönetici panelinden onaylanabilir.',
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

void showAccountStatementDialog(BuildContext context, AppState appState) {
  final customer = appState.currentCustomer;
  final notes = appState.customerNotes;
  final total = appState.getCustomerTotalAmount(customer.id);
  final paid = appState.getCustomerPaidAmount(customer.id);
  final remaining = appState.getCustomerRemainingAmount(customer.id);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return IosGlassSheet(
        maxHeightFactor: 0.88,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_richtext,
                    color: Color(0xFF64D2FF),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Müşteri Cari & Senet Hesap Ekstresi',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Sözleşme No: ${customer.contractNo} • Tarih: 05.11.2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.16)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                        width: 0.7,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DEMİRTÜRK İNŞAAT & YAPI MALZ. SAN. TİC. LTD. ŞTİ. - RESMİ SENET ÇİZELGESİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64D2FF),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow('Müşteri / Unvan:', customer.name),
                        _buildInfoRow('TCKN / VKN:', customer.tcOrTaxNo),
                        _buildInfoRow('Telefon:', customer.phone),
                        _buildInfoRow('Sözleşme Kodu:', customer.contractNo),
                        Divider(
                          height: 20,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatMini(
                                'Toplam Senet',
                                formatCurrency(total),
                                Colors.white,
                              ),
                            ),
                            Expanded(
                              child: _buildStatMini(
                                'Ödenen',
                                formatCurrency(paid),
                                const Color(0xFF30D158),
                              ),
                            ),
                            Expanded(
                              child: _buildStatMini(
                                'Kalan Borç',
                                formatCurrency(remaining),
                                const Color(0xFFFF453A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Senet / Taksit Detay Listesi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...notes.map((n) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: n.status.bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: n.status.color.withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              '${n.installmentIndex}/${n.totalInstallments}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: n.status.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${n.senetNo} • Vade: ${formatShortDate(n.dueDate)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  n.paidDate != null
                                      ? 'Ödeme Tarihi: ${formatShortDate(n.paidDate!)}'
                                      : n.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrency(n.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: n.status.color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
              child: Row(
                children: [
                  Expanded(
                    child: IosGlassButton(
                      isSecondaryGlass: true,
                      icon: CupertinoIcons.doc_on_doc_fill,
                      label: 'Özeti Kopyala',
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onTap: () {
                        final buffer = StringBuffer();
                        buffer.writeln('=== MÜŞTERİ SENET HESAP EKSTRESİ ===');
                        buffer.writeln('Müşteri: ${customer.name}');
                        buffer.writeln('Sözleşme No: ${customer.contractNo}');
                        buffer.writeln(
                            'Toplam: ${formatCurrency(total)} | Ödenen: ${formatCurrency(paid)} | Kalan: ${formatCurrency(remaining)}');
                        buffer.writeln('------------------------------------');
                        for (final n in notes) {
                          buffer.writeln(
                              '${n.senetNo} | Vade: ${formatShortDate(n.dueDate)} | ${formatCurrency(n.amount)} | ${n.status.label}');
                        }
                        Clipboard.setData(
                            ClipboardData(text: buffer.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Hesap ekstresi metin olarak kopyalandı!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IosGlassButton(
                      icon: CupertinoIcons.arrow_down_doc_fill,
                      label: 'PDF Ekstre İndir',
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onTap: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0A84FF),
                            content: Text(
                              '${customer.contractNo}_Hesap_Ekstresi.pdf cihazınıza indirildi.',
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
          ],
        ),
      );
    },
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatMini(String title, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
}

void showNotificationsSheet(BuildContext context, AppState appState) {
  appState.markAllNotificationsRead();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final list = appState.customerNotifications;
      return IosGlassSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
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
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.bell_fill,
                    color: Color(0xFF64D2FF),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bildirimler & Vade Hatırlatmaları',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ],
              ),
              Divider(color: Colors.white.withValues(alpha: 0.16)),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Henüz bildiriminiz bulunmuyor.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 16,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      IconData icon = CupertinoIcons.bell_fill;
                      Color color = const Color(0xFF64D2FF);
                      if (item.type == 'overdue') {
                        icon = CupertinoIcons.exclamationmark_triangle_fill;
                        color = const Color(0xFFFF453A);
                      } else if (item.type == 'approved') {
                        icon = CupertinoIcons.checkmark_seal_fill;
                        color = const Color(0xFF30D158);
                      } else if (item.type == 'message') {
                        icon = CupertinoIcons.chat_bubble_2_fill;
                        color = const Color(0xFFBF5AF2);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: color.withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatShortDate(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
