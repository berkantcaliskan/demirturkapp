import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/portal_repository.dart';
import '../../widgets/website_blurred_background.dart';

void showIbanSheet(BuildContext context, AppState appState) {
  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      final isDark = AppGlass.isDark(ctx);
      final textPrimary = AppGlass.textPrimary(ctx);
      final textSecondary = AppGlass.textSecondary(ctx);
      final textMuted = AppGlass.textMuted(ctx);
      final bankAccounts = appState.bankAccounts;

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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : const Color(0xFF0F172A).withValues(alpha: 0.16),
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
                      color: AppGlass.subtleSurface(ctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppGlass.dividerColor(ctx),
                        width: 0.7,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.building_2_fill,
                      color: textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şirket Banka & IBAN Bilgileri',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: textPrimary,
                          ),
                        ),
                        if (bankAccounts.isNotEmpty)
                          Text(
                            'FAST / EFT / Havale açıklamasına Senet No yazınız',
                            style: TextStyle(fontSize: 12, color: textMuted),
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
                      color: textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppGlass.dividerColor(ctx)),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  if (bankAccounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Banka hesabı bilgisi henüz eklenmemiş. Ödeme bilgileri için muhasebeyle iletişime geçin.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  if (bankAccounts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(13),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(ctx),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppGlass.dividerColor(ctx),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            color: textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Alıcı Unvanı: ${bankAccounts.first.accountHolder}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
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
                                  text: bankAccounts.first.accountHolder,
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
                  ...bankAccounts.map((bank) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(ctx),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppGlass.dividerColor(ctx),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppGlass.subtleSurface(ctx),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bank.branchName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
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
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppGlass.dividerColor(ctx),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bank.iban,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                      fontFamily: 'Plus Jakarta Sans',
                                      color: textPrimary,
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
  PortalRepository? repository,
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

  PromissoryNote selectedNote =
      preselectedNote != null &&
          unpaidNotes.any((n) => n.id == preselectedNote.id)
      ? unpaidNotes.firstWhere((n) => n.id == preselectedNote.id)
      : unpaidNotes.first;

  String selectedBank = 'HAVALE / EFT (Ziraat Bankası)';
  String selectedFileName = repository == null
      ? 'dekont_${selectedNote.senetNo.toLowerCase().replaceAll('-', '_')}.pdf'
      : 'Dosya seçilmedi';
  Uint8List? selectedFileBytes;
  final noteController = TextEditingController();

  final bankOptions = [
    'HAVALE / EFT (Ziraat Bankası)',
    'FAST / Havale (Garanti BBVA)',
    'HAVALE / EFT (Türkiye İş Bankası)',
    'Kredi Kartı / Sanal POS Makbuzu',
    'Şirket veznesine elden ödeme makbuzu',
  ];

  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = AppGlass.isDark(context);
          final textPrimary = AppGlass.textPrimary(context);
          final textSecondary = AppGlass.textSecondary(context);
          final textMuted = AppGlass.textMuted(context);
          final activeBg = isDark ? Colors.white : const Color(0xFF1E293B);
          final activeFg = isDark ? const Color(0xFF0F172A) : Colors.white;

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
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.28)
                              : const Color(0xFF0F172A).withValues(alpha: 0.16),
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
                            color: AppGlass.subtleSurface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppGlass.dividerColor(context),
                              width: 0.7,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.arrow_up_doc_fill,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dekont Yükle & Ödeme Bildir',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Ödeme belgenizi yükleyin, muhasebe onayına iletilsin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
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
                            color: textMuted,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'İlgili Senet Seçimi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
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
                                    ? activeBg
                                    : AppGlass.subtleSurface(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active
                                      ? activeBg
                                      : AppGlass.dividerColor(context),
                                  width: 0.7,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${note.senetNo} • ${formatCurrency(note.amount)}',
                                  style: TextStyle(
                                    color: active ? activeFg : textPrimary,
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
                    Text(
                      'Ödeme Yöntemi / Banka',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
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
                                  ? activeBg
                                  : AppGlass.subtleSurface(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? activeBg
                                    : AppGlass.dividerColor(context),
                                width: 0.7,
                              ),
                            ),
                            child: Text(
                              b,
                              style: TextStyle(
                                color: active ? activeFg : textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dekont Dosyası (PDF veya Görsel)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppGlass.dividerColor(context),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.doc_fill,
                            color: textPrimary,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFileName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  selectedFileBytes == null
                                      ? 'PDF veya görsel seçin (en fazla 10 MB)'
                                      : '${(selectedFileBytes!.length / 1024).toStringAsFixed(0)} KB • yüklemeye hazır',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textMuted,
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
                            onTap: () async {
                              if (repository == null) {
                                setModalState(() {
                                  selectedFileName =
                                      'dekont_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                });
                                return;
                              }
                              try {
                                final files = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const [
                                    'pdf',
                                    'jpg',
                                    'jpeg',
                                    'png',
                                  ],
                                );
                                if (files.isEmpty || !context.mounted) return;
                                final file = files.first;
                                final bytes = await file.readAsBytes();
                                if (!context.mounted) return;
                                if (bytes.length > 10 * 1024 * 1024) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Dosya boyutu 10 MB sınırını aşıyor.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() {
                                  selectedFileName = file.name;
                                  selectedFileBytes = bytes;
                                });
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Dosya açılamadı: $error'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Açıklama / Not (İsteğe Bağlı)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: noteController,
                      maxLines: 2,
                      placeholder: 'Örn: Eşimin hesabından gönderildi, açıklama kısmına senet no yazıldı...',
                      placeholderStyle: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                      ),
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: IosGlassButton(
                        icon: CupertinoIcons.paperplane_fill,
                        label:
                            '${formatCurrency(selectedNote.amount)} Ödeme Bildirimini Gönder',
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onTap: () async {
                          final customerNote =
                              noteController.text.trim().isEmpty
                              ? '$selectedBank üzerinden ödeme yapıldı.'
                              : noteController.text.trim();
                          if (repository == null) {
                            appState.submitPaymentReceipt(
                              noteId: selectedNote.id,
                              receiptFileName: selectedFileName,
                              paymentMethod: selectedBank,
                              receiptNote: customerNote,
                            );
                          } else {
                            final bytes = selectedFileBytes;
                            if (bytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ödeme bildirimini göndermeden önce dekont seçin.',
                                  ),
                                ),
                              );
                              return;
                            }
                            String? uploadedPath;
                            try {
                              final extension = selectedFileName
                                  .split('.')
                                  .last
                                  .toLowerCase();
                              final contentType = switch (extension) {
                                'pdf' => 'application/pdf',
                                'png' => 'image/png',
                                _ => 'image/jpeg',
                              };
                              uploadedPath = await repository
                                  .uploadPaymentReceipt(
                                    customerId: appState.currentCustomer.id,
                                    fileName: selectedFileName,
                                    bytes: bytes,
                                    contentType: contentType,
                                  );
                              await repository.submitPaymentReceipt(
                                noteId: selectedNote.id,
                                customerId: appState.currentCustomer.id,
                                receiptObjectPath: uploadedPath,
                                paymentMethod: selectedBank,
                                customerNote: customerNote,
                              );
                            } catch (error) {
                              if (uploadedPath != null) {
                                try {
                                  await repository.deletePaymentReceipt(
                                    uploadedPath,
                                  );
                                } catch (_) {}
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Dekont gönderilemedi: $error',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          if (!ctx.mounted || !context.mounted) return;
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

  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      final isDark = AppGlass.isDark(ctx);
      final textPrimary = AppGlass.textPrimary(ctx);
      final textSecondary = AppGlass.textSecondary(ctx);
      final textMuted = AppGlass.textMuted(ctx);

      return IosGlassSheet(
        maxHeightFactor: 0.88,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : const Color(0xFF0F172A).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.doc_richtext,
                    color: textPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Müşteri Cari & Senet Hesap Ekstresi',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Sözleşme No: ${customer.contractNo} • Tarih: 05.11.2026',
                          style: TextStyle(fontSize: 12, color: textMuted),
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
                      color: textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppGlass.dividerColor(ctx)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(ctx),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppGlass.dividerColor(ctx),
                        width: 0.7,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEMİRTÜRK İNŞAAT & YAPI MALZ. SAN. TİC. LTD. ŞTİ. - RESMİ SENET ÇİZELGESİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(ctx, 'Müşteri / Unvan:', customer.name),
                        _buildInfoRow(ctx, 'TCKN / VKN:', customer.tcOrTaxNo),
                        _buildInfoRow(ctx, 'Telefon:', customer.phone),
                        _buildInfoRow(
                          ctx,
                          'Sözleşme Kodu:',
                          customer.contractNo,
                        ),
                        Divider(height: 20, color: AppGlass.dividerColor(ctx)),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatMini(
                                ctx,
                                'Toplam Senet',
                                formatCurrency(total),
                                textPrimary,
                              ),
                            ),
                            Expanded(
                              child: _buildStatMini(
                                ctx,
                                'Ödenen',
                                formatCurrency(paid),
                                const Color(0xFF10B981),
                              ),
                            ),
                            Expanded(
                              child: _buildStatMini(
                                ctx,
                                'Kalan Borç',
                                formatCurrency(remaining),
                                const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Senet / Taksit Detay Listesi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
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
                        color: AppGlass.subtleSurface(ctx),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppGlass.dividerColor(ctx),
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
                              color: AppGlass.subtleSurface(ctx),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppGlass.dividerColor(ctx),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              '${n.installmentIndex}/${n.totalInstallments}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  n.paidDate != null
                                      ? 'Ödeme Tarihi: ${formatShortDate(n.paidDate!)}'
                                      : n.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textMuted,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: n.status == NoteStatus.overdue
                                      ? const Color(0xFFE11D48)
                                      : textSecondary,
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
                          'Toplam: ${formatCurrency(total)} | Ödenen: ${formatCurrency(paid)} | Kalan: ${formatCurrency(remaining)}',
                        );
                        buffer.writeln('------------------------------------');
                        for (final n in notes) {
                          buffer.writeln(
                            '${n.senetNo} | Vade: ${formatShortDate(n.dueDate)} | ${formatCurrency(n.amount)} | ${n.status.label}',
                          );
                        }
                        Clipboard.setData(
                          ClipboardData(text: buffer.toString()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hesap ekstresi metin olarak kopyalandı!',
                            ),
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
                            backgroundColor: const Color(0xFF1E293B),
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

Widget _buildInfoRow(BuildContext context, String label, String value) {
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
              color: AppGlass.textMuted(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppGlass.textPrimary(context),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatMini(
  BuildContext context,
  String title,
  String value,
  Color color,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(fontSize: 11, color: AppGlass.textMuted(context)),
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

Future<void> showNotificationsSheet(
  BuildContext context,
  AppState appState, {
  PortalRepository? repository,
}) async {
  if (repository != null) {
    try {
      appState.replaceCustomerNotifications(
        await repository.loadMyNotifications(),
      );
      await repository.markAllMyNotificationsRead();
      appState.replaceCustomerNotifications(
        await repository.loadMyNotifications(),
      );
    } catch (error) {
      debugPrint('Could not refresh inbox: $error');
    }
  } else {
    appState.markAllNotificationsRead();
  }
  if (!context.mounted) return;
  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      final isDark = AppGlass.isDark(ctx);
      final textPrimary = AppGlass.textPrimary(ctx);
      final textSecondary = AppGlass.textSecondary(ctx);
      final textMuted = AppGlass.textMuted(ctx);
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : const Color(0xFF0F172A).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(CupertinoIcons.bell_fill, color: textPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bildirimler & Vade Hatırlatmaları',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
              Divider(color: AppGlass.dividerColor(ctx)),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Henüz bildiriminiz bulunmuyor.',
                    style: TextStyle(color: textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 16, color: AppGlass.dividerColor(ctx)),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      IconData icon = CupertinoIcons.bell_fill;
                      Color color = textPrimary;
                      if (item.type == 'overdue') {
                        icon = CupertinoIcons.exclamationmark_triangle_fill;
                        color = const Color(0xFFE11D48);
                      } else if (item.type == 'approved') {
                        icon = CupertinoIcons.checkmark_seal_fill;
                        color = const Color(0xFF10B981);
                      } else if (item.type == 'message') {
                        icon = CupertinoIcons.chat_bubble_2_fill;
                        color = textSecondary;
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(ctx),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: AppGlass.dividerColor(ctx),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatShortDate(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
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
