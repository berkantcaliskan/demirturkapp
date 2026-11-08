import 'package:flutter/material.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  UserRole _currentRole = UserRole.customer;
  String _selectedCustomerId = 'cust_1';
  ThemeMode _themeMode = ThemeMode.light;

  UserRole get currentRole => _currentRole;
  String get selectedCustomerId => _selectedCustomerId;
  ThemeMode get themeMode => _themeMode;

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleThemeMode(BuildContext context) {
    final currentlyDark = isDark(context);
    _themeMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Customer get currentCustomer =>
      _customers.firstWhere((c) => c.id == _selectedCustomerId);

  SalesAdvisor get currentSalesAdvisor => _salesAdvisors.firstWhere(
        (a) => a.id == currentCustomer.assignedAdvisorId,
        orElse: () => _salesAdvisors.first,
      );

  List<SalesAdvisor> get salesAdvisors => List.unmodifiable(_salesAdvisors);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<PromissoryNote> get allNotes => List.unmodifiable(_notes);
  List<BankAccount> get bankAccounts => List.unmodifiable(_bankAccounts);
  List<SupportTicket> get allTickets => List.unmodifiable(_tickets);

  List<PromissoryNote> get customerNotes => _notes
      .where((n) => n.customerId == _selectedCustomerId)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<SupportTicket> get customerTickets => _tickets
      .where((t) => t.customerId == _selectedCustomerId)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<AppNotification> get customerNotifications => _notifications
      .where((n) => n.customerId == _selectedCustomerId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadNotificationCount =>
      customerNotifications.where((n) => !n.isRead).length;

  int get pendingVerificationCount =>
      _notes.where((n) => n.status == NoteStatus.verifying).length;

  final List<BankAccount> _bankAccounts = const [
    BankAccount(
      bankName: 'Ziraat Bankası',
      accountHolder: 'DEMİRTÜRK İNŞAAT & YAPI MALZ. SAN. TİC. LTD. ŞTİ.',
      iban: 'TR33 0001 0017 4567 8910 1150 01',
      branchName: 'Karasu Şubesi (1745)',
      brandColor: Color(0xFFE11D48),
    ),
    BankAccount(
      bankName: 'Garanti BBVA',
      accountHolder: 'DEMİRTÜRK İNŞAAT & YAPI MALZ. SAN. TİC. LTD. ŞTİ.',
      iban: 'TR76 0006 2000 4120 0006 2988 40',
      branchName: 'Sakarya Ticari Şube (0412)',
      brandColor: Color(0xFF059669),
    ),
    BankAccount(
      bankName: 'Türkiye İş Bankası',
      accountHolder: 'DEMİRTÜRK İNŞAAT & YAPI MALZ. SAN. TİC. LTD. ŞTİ.',
      iban: 'TR19 0006 4000 0014 2300 8891 02',
      branchName: 'Karasu Şubesi (4230)',
      brandColor: Color(0xFF1D4ED8),
    ),
  ];

  final List<SalesAdvisor> _salesAdvisors = [
    SalesAdvisor(
      id: 'adv_1',
      name: 'Selim Demirtürk',
      roleTitle: 'Kıdemli Satış Danışmanı',
      phone: '+90 543 667 34 54',
      photoUrl:
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=800&q=85',
      photoUpdatedAt: DateTime(2026, 11, 1, 9, 0),
    ),
    SalesAdvisor(
      id: 'adv_2',
      name: 'Elif Karahan',
      roleTitle: 'Kurumsal Satış Danışmanı',
      phone: '+90 543 667 34 54',
      photoUrl:
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=800&q=85',
      photoUpdatedAt: DateTime(2026, 11, 1, 9, 0),
    ),
    SalesAdvisor(
      id: 'adv_3',
      name: 'Burak Aydın',
      roleTitle: 'Proje Satış Danışmanı',
      phone: '+90 543 667 34 54',
      photoUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=800&q=85',
      photoUpdatedAt: DateTime(2026, 11, 1, 9, 0),
    ),
  ];

  final List<Customer> _customers = [
    const Customer(
      id: 'cust_1',
      name: 'Ahmet Yılmaz',
      tcOrTaxNo: '28491048216',
      phone: '+90 532 418 72 90',
      email: 'ahmet.yilmaz@eposta.com',
      address: 'Yalı Mah. Yeni Şehir 3. Etap A Blok Daire 12 Karasu / Sakarya',
      contractNo: 'DMR-2026-0148',
      assignedAdvisorId: 'adv_1',
    ),
    const Customer(
      id: 'cust_2',
      name: 'Kaya Mimarlık & Yatırım Ltd. Şti.',
      tcOrTaxNo: '5280419820',
      phone: '+90 544 892 15 33',
      email: 'muhasebe@kayayatirim.com.tr',
      address: 'Aziziye Mah. Asel Doğa Evleri 2 B Blok Daire 4 Karasu / Sakarya',
      contractNo: 'DMR-2026-0205',
      assignedAdvisorId: 'adv_2',
    ),
    const Customer(
      id: 'cust_3',
      name: 'Zeynep Demir',
      tcOrTaxNo: '49102837462',
      phone: '+90 505 671 88 12',
      email: 'zeynepdemir@eposta.com',
      address: 'Yalı Mah. Plaj Cd. Almina Evleri 2 Daire 7 Karasu / Sakarya',
      contractNo: 'DMR-2026-0312',
      assignedAdvisorId: 'adv_3',
    ),
  ];

  final List<PromissoryNote> _notes = [
    // Ahmet Yılmaz (cust_1) - Yeni Şehir 3. Etap 6 Taksitlik Örnek Plan
    PromissoryNote(
      id: 'note_101',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-001',
      installmentIndex: 1,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2026, 8, 15),
      paidDate: DateTime(2026, 8, 14),
      status: NoteStatus.paid,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 1. Elden Senet',
      receiptFileName: 'ziraat_dekont_agustos.pdf',
      paymentMethod: 'HAVALE / EFT (Ziraat Bankası)',
    ),
    PromissoryNote(
      id: 'note_102',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-002',
      installmentIndex: 2,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2026, 9, 15),
      paidDate: DateTime(2026, 9, 15),
      status: NoteStatus.paid,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 2. Elden Senet',
      receiptFileName: 'garanti_fast_eylul.pdf',
      paymentMethod: 'FAST / Havale (Garanti BBVA)',
    ),
    PromissoryNote(
      id: 'note_103',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-003',
      installmentIndex: 3,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2026, 10, 15),
      status: NoteStatus.overdue,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 3. Elden Senet',
    ),
    PromissoryNote(
      id: 'note_104',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-004',
      installmentIndex: 4,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2026, 11, 15),
      status: NoteStatus.verifying,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 4. Elden Senet',
      receiptFileName: 'dekont_kasim_2026.jpg',
      receiptNote: 'Ziraat Bankası IBAN hesabınıza EFT yapıldı.',
      submittedAt: DateTime(2026, 11, 4, 11, 20),
      paymentMethod: 'HAVALE / EFT (Ziraat Bankası)',
    ),
    PromissoryNote(
      id: 'note_105',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-005',
      installmentIndex: 5,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2026, 12, 15),
      status: NoteStatus.pending,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 5. Elden Senet',
    ),
    PromissoryNote(
      id: 'note_106',
      customerId: 'cust_1',
      senetNo: 'SNT-2026-006',
      installmentIndex: 6,
      totalInstallments: 6,
      amount: 25000.0,
      dueDate: DateTime(2027, 1, 15),
      status: NoteStatus.pending,
      description: 'Yeni Şehir 3. Etap (2+1 Teraslı Daire) - 6. Elden Senet',
    ),

    // Kaya Mimarlık (cust_2) - Asel Doğa Evleri 2
    PromissoryNote(
      id: 'note_201',
      customerId: 'cust_2',
      senetNo: 'SNT-2026-101',
      installmentIndex: 1,
      totalInstallments: 4,
      amount: 85000.0,
      dueDate: DateTime(2026, 9, 20),
      paidDate: DateTime(2026, 9, 19),
      status: NoteStatus.paid,
      description: 'Asel Doğa Evleri 2 (Bahçe Teraslı Daire) - 1. Elden Senet',
      receiptFileName: 'isbank_dekont_01.pdf',
      paymentMethod: 'EFT (Türkiye İş Bankası)',
    ),
    PromissoryNote(
      id: 'note_202',
      customerId: 'cust_2',
      senetNo: 'SNT-2026-102',
      installmentIndex: 2,
      totalInstallments: 4,
      amount: 85000.0,
      dueDate: DateTime(2026, 10, 20),
      status: NoteStatus.verifying,
      description: 'Asel Doğa Evleri 2 (Bahçe Teraslı Daire) - 2. Elden Senet',
      receiptFileName: 'kaya_ekim_dekont.pdf',
      receiptNote: 'Şirket hesabımızdan Garanti BBVA hesabınıza gönderildi.',
      submittedAt: DateTime(2026, 11, 4, 09, 45),
      paymentMethod: 'HAVALE / EFT (Garanti BBVA)',
    ),
    PromissoryNote(
      id: 'note_203',
      customerId: 'cust_2',
      senetNo: 'SNT-2026-103',
      installmentIndex: 3,
      totalInstallments: 4,
      amount: 85000.0,
      dueDate: DateTime(2026, 11, 20),
      status: NoteStatus.pending,
      description: 'Asel Doğa Evleri 2 (Bahçe Teraslı Daire) - 3. Elden Senet',
    ),
    PromissoryNote(
      id: 'note_204',
      customerId: 'cust_2',
      senetNo: 'SNT-2026-104',
      installmentIndex: 4,
      totalInstallments: 4,
      amount: 85000.0,
      dueDate: DateTime(2026, 12, 20),
      status: NoteStatus.pending,
      description: 'Asel Doğa Evleri 2 (Bahçe Teraslı Daire) - 4. Elden Senet',
    ),

    // Zeynep Demir (cust_3) - Almina Evleri 2
    PromissoryNote(
      id: 'note_301',
      customerId: 'cust_3',
      senetNo: 'SNT-2026-201',
      installmentIndex: 1,
      totalInstallments: 3,
      amount: 42500.0,
      dueDate: DateTime(2026, 10, 10),
      paidDate: DateTime(2026, 10, 9),
      status: NoteStatus.paid,
      description: 'Almina Evleri 2 (2+1 Sahil Dairesi) - 1. Elden Senet',
      paymentMethod: 'FAST (Ziraat Bankası)',
    ),
    PromissoryNote(
      id: 'note_302',
      customerId: 'cust_3',
      senetNo: 'SNT-2026-202',
      installmentIndex: 2,
      totalInstallments: 3,
      amount: 42500.0,
      dueDate: DateTime(2026, 11, 10),
      status: NoteStatus.pending,
      description: 'Almina Evleri 2 (2+1 Sahil Dairesi) - 2. Elden Senet',
    ),
    PromissoryNote(
      id: 'note_303',
      customerId: 'cust_3',
      senetNo: 'SNT-2026-203',
      installmentIndex: 3,
      totalInstallments: 3,
      amount: 42500.0,
      dueDate: DateTime(2026, 12, 10),
      status: NoteStatus.pending,
      description: 'Almina Evleri 2 (2+1 Sahil Dairesi) - 3. Elden Senet',
    ),
  ];

  final List<SupportTicket> _tickets = [
    SupportTicket(
      id: 'tck_1',
      customerId: 'cust_1',
      subject: 'SNT-2026-003 Gecikmiş Senet Ödeme Tarihi Hakkında',
      category: 'Finans & Muhasebe',
      channel: 'finance',
      relatedSenetNo: 'SNT-2026-003',
      isResolved: false,
      updatedAt: DateTime(2026, 11, 4, 13, 15),
      messages: [
        ChatMessage(
          id: 'msg_1',
          isFromAdmin: false,
          senderName: 'Ahmet Yılmaz',
          text:
              'Merhabalar, 15 Ekim vadeli SNT-2026-003 numaralı senedimin ödemesini bu Cuma günü IBAN hesabınıza göndereceğim. Bilginize sunarım.',
          timestamp: DateTime(2026, 11, 4, 12, 40),
        ),
        ChatMessage(
          id: 'msg_2',
          isFromAdmin: true,
          senderName: 'Finans & Muhasebe Uzmanı',
          text:
              'Merhaba Ahmet Bey, bilgilendirmeniz için teşekkür ederiz. Ödemeyi gerçekleştirdikten sonra uygulama üzerinden dekontu yükleyebilirsiniz, işleminiz hemen onaylanacaktır.',
          timestamp: DateTime(2026, 11, 4, 13, 15),
        ),
      ],
    ),
    SupportTicket(
      id: 'tck_adv_1',
      customerId: 'cust_1',
      subject: 'Selim Demirtürk • Satış Danışmanı Görüşmesi',
      category: 'Satış Danışmanım',
      channel: 'advisor',
      isResolved: false,
      updatedAt: DateTime(2026, 11, 5, 11, 30),
      messages: [
        ChatMessage(
          id: 'msg_adv_1',
          isFromAdmin: true,
          senderName: 'Selim Demirtürk',
          text:
              'Merhaba Ahmet Bey, Yenişehir 3. Etap A Blok Daire 12 konutunuzla ilgili her türlü sorunuzda doğrudan buradan bana ulaşabilirsiniz.',
          timestamp: DateTime(2026, 11, 5, 11, 30),
        ),
      ],
    ),
    SupportTicket(
      id: 'tck_2',
      customerId: 'cust_2',
      subject: 'Ekim Ayı Filo Senedi Dekont Bildirimi',
      category: 'Finans & Muhasebe',
      channel: 'finance',
      relatedSenetNo: 'SNT-2026-102',
      isResolved: false,
      updatedAt: DateTime(2026, 11, 4, 10, 05),
      messages: [
        ChatMessage(
          id: 'msg_3',
          isFromAdmin: false,
          senderName: 'Kaya İnşaat & Mimarlık Ltd. Şti.',
          text:
              'SNT-2026-102 nolu 85.000 TL tutarındaki senedimizin ödemesini Garanti BBVA hesabınıza EFT yaptık, dekontu sisteme yükledik. Onayınızı rica ederiz.',
          timestamp: DateTime(2026, 11, 4, 10, 05),
          attachmentName: 'kaya_insaat_ekim_dekont.pdf',
        ),
      ],
    ),
  ];

  final List<AppNotification> _notifications = [
    AppNotification(
      id: 'notif_1',
      customerId: 'cust_1',
      title: 'Gecikmiş Senet Hatırlatması',
      body:
          'SNT-2026-003 numaralı (25.000,00 ₺) senedinizin vade tarihi (15.10.2026) geçmiştir. Ödeme yaptıysanız lütfen dekont yükleyiniz.',
      createdAt: DateTime(2026, 11, 3, 10, 00),
      isRead: false,
      type: 'overdue',
    ),
    AppNotification(
      id: 'notif_2',
      customerId: 'cust_1',
      title: 'Finans Departmanından Yeni Mesaj',
      body:
          'SNT-2026-003 Gecikmiş Senet Ödeme Tarihi Hakkında konulu destek talebinize yanıt verildi.',
      createdAt: DateTime(2026, 11, 4, 13, 15),
      isRead: false,
      type: 'message',
    ),
    AppNotification(
      id: 'notif_3',
      customerId: 'cust_1',
      title: 'Dekontunuz İncelemeye Alındı',
      body:
          'SNT-2026-004 numaralı senediniz için yüklediğiniz dekont muhasebe birimine iletilmiştir.',
      createdAt: DateTime(2026, 11, 4, 11, 20),
      isRead: true,
      type: 'approved',
    ),
  ];

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void selectCustomer(String customerId) {
    _selectedCustomerId = customerId;
    notifyListeners();
  }

  // Customer totals
  double getCustomerTotalAmount(String customerId) {
    return _notes
        .where((n) => n.customerId == customerId)
        .fold(0.0, (sum, n) => sum + n.amount);
  }

  double getCustomerPaidAmount(String customerId) {
    return _notes
        .where((n) => n.customerId == customerId && n.status == NoteStatus.paid)
        .fold(0.0, (sum, n) => sum + n.amount);
  }

  double getCustomerRemainingAmount(String customerId) {
    return _notes
        .where((n) => n.customerId == customerId && n.status != NoteStatus.paid)
        .fold(0.0, (sum, n) => sum + n.amount);
  }

  double getCustomerOverdueAmount(String customerId) {
    return _notes
        .where(
            (n) => n.customerId == customerId && n.status == NoteStatus.overdue)
        .fold(0.0, (sum, n) => sum + n.amount);
  }

  // Company-wide totals (for Admin)
  double get companyTotalReceivables =>
      _notes.fold(0.0, (sum, n) => sum + n.amount);

  double get companyTotalCollected => _notes
      .where((n) => n.status == NoteStatus.paid)
      .fold(0.0, (sum, n) => sum + n.amount);

  double get companyTotalOverdue => _notes
      .where((n) => n.status == NoteStatus.overdue)
      .fold(0.0, (sum, n) => sum + n.amount);

  double get companyTotalVerifying => _notes
      .where((n) => n.status == NoteStatus.verifying)
      .fold(0.0, (sum, n) => sum + n.amount);

  Customer getCustomerById(String id) {
    return _customers.firstWhere(
      (c) => c.id == id,
      orElse: () => _customers.first,
    );
  }

  // Customer action: Submit payment receipt / notification
  void submitPaymentReceipt({
    required String noteId,
    required String receiptFileName,
    required String paymentMethod,
    required String receiptNote,
  }) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notes[index];
    _notes[index] = note.copyWith(
      status: NoteStatus.verifying,
      receiptFileName: receiptFileName,
      paymentMethod: paymentMethod,
      receiptNote: receiptNote,
      submittedAt: DateTime.now(),
      rejectionReason: null,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        customerId: note.customerId,
        title: 'Ödeme Bildiriminiz Alındı',
        body:
            '${note.senetNo} numaralı senediniz için dekont ($receiptFileName) başarıyla yüklendi. Muhasebe onayından sonra durum güncellenecektir.',
        createdAt: DateTime.now(),
        type: 'approved',
      ),
    );

    notifyListeners();
  }

  // Admin action: Approve payment receipt or mark note as paid
  void approveNotePayment(String noteId, {String? customMethod}) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notes[index];
    _notes[index] = note.copyWith(
      status: NoteStatus.paid,
      paidDate: DateTime.now(),
      paymentMethod:
          customMethod ?? note.paymentMethod ?? 'Şirket Onayı / Elden Tahsilat',
      rejectionReason: null,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        customerId: note.customerId,
        title: 'Ödemeniz Onaylandı ✓',
        body:
            '${note.senetNo} numaralı (${formatCurrency(note.amount)}) senedinizin ödemesi şirket muhasebesi tarafından onaylanmıştır. Teşekkür ederiz.',
        createdAt: DateTime.now(),
        type: 'approved',
      ),
    );

    notifyListeners();
  }

  // Admin action: Reject payment receipt
  void rejectNotePayment(String noteId, String reason) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notes[index];
    final isPastDue = note.dueDate.isBefore(DateTime(2026, 11, 4));
    _notes[index] = note.copyWith(
      status: isPastDue ? NoteStatus.overdue : NoteStatus.pending,
      rejectionReason: reason,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        customerId: note.customerId,
        title: 'Dekont Bildirimi Reddedildi',
        body:
            '${note.senetNo} numaralı senediniz için yapılan ödeme bildirimi onaylanamadı. Açıklama: $reason',
        createdAt: DateTime.now(),
        type: 'overdue',
      ),
    );

    notifyListeners();
  }

  // Admin action: Send reminder notification to customer for a note
  void sendPaymentReminder(PromissoryNote note) {
    _notifications.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        customerId: note.customerId,
        title: 'Şirket Ödeme Hatırlatması',
        body:
            'Sayın müşterimiz, ${note.senetNo} numaralı ve ${formatShortDate(note.dueDate)} vadeli ${formatCurrency(note.amount)} tutarındaki senedinizin ödemesini hatırlatmak isteriz.',
        createdAt: DateTime.now(),
        type: 'reminder',
      ),
    );
    notifyListeners();
  }

  // Admin action: Create installment plan (1 or multiple promissory notes)
  void createInstallmentPlan({
    required String customerId,
    required double monthlyAmount,
    required int installmentCount,
    required DateTime firstDueDate,
    required String descriptionPrefix,
  }) {
    final existingCount = _notes.length;
    for (int i = 0; i < installmentCount; i++) {
      final dueDate = DateTime(
        firstDueDate.year,
        firstDueDate.month + i,
        firstDueDate.day,
      );
      final senetNumber =
          'SNT-2026-${(existingCount + i + 301).toString().padLeft(3, '0')}';

      _notes.add(
        PromissoryNote(
          id: 'note_${DateTime.now().millisecondsSinceEpoch}_$i',
          customerId: customerId,
          senetNo: senetNumber,
          installmentIndex: i + 1,
          totalInstallments: installmentCount,
          amount: monthlyAmount,
          dueDate: dueDate,
          status: dueDate.isBefore(DateTime(2026, 11, 4))
              ? NoteStatus.overdue
              : NoteStatus.pending,
          description: '$descriptionPrefix - ${i + 1}. Senet',
        ),
      );
    }

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customerId,
        title: 'Yeni Senet / Ödeme Planı Tanımlandı',
        body:
            '$descriptionPrefix kapsamında $installmentCount adet (${formatCurrency(monthlyAmount)} / ay) yeni senet planınız hesabınıza tanımlanmıştır.',
        createdAt: DateTime.now(),
        type: 'reminder',
      ),
    );

    notifyListeners();
  }

  // Admin action: Add a new customer
  String addCustomer({
    required String name,
    required String tcOrTaxNo,
    required String phone,
    required String email,
    required String address,
    required String contractNo,
  }) {
    final id = 'cust_${_customers.length + 1}';
    _customers.add(
      Customer(
        id: id,
        name: name,
        tcOrTaxNo: tcOrTaxNo,
        phone: phone,
        email: email,
        address: address,
        contractNo: contractNo,
      ),
    );
    notifyListeners();
    return id;
  }

  // Danışman fotoğrafını güncelledikçe otomatik olarak tüm ekranlarda yenilenir
  void updateSalesAdvisorPhoto(String advisorId, String newPhotoUrl) {
    final index = _salesAdvisors.indexWhere((a) => a.id == advisorId);
    if (index == -1) return;
    _salesAdvisors[index] = _salesAdvisors[index].copyWith(
      photoUrl: newPhotoUrl,
      photoUpdatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Müşterinin ilgili iletişim kanalındaki (advisor | finance | general) aktif konuşmasını getirir veya başlatır
  SupportTicket getOrCreateChannelTicket(String channel) {
    final customer = currentCustomer;
    final existingIndex = _tickets.indexWhere(
      (t) => t.customerId == customer.id && t.channel == channel,
    );
    if (existingIndex != -1) {
      return _tickets[existingIndex];
    }

    final advisor = currentSalesAdvisor;
    final String subject;
    final String category;
    final String welcomeSender;
    final String welcomeText;

    if (channel == 'advisor') {
      subject = '${advisor.name} • Satış Danışmanı Görüşmesi';
      category = 'Satış Danışmanım';
      welcomeSender = advisor.name;
      welcomeText =
          'Merhaba ${customer.name}, ${customer.projectTitle} (${customer.unitSubtitle}) konutunuzla ilgili her konuda bana doğrudan buradan yazabilirsiniz.';
    } else if (channel == 'finance') {
      subject = 'Finans Uzmanı & Muhasebe Görüşmesi';
      category = 'Finans & Muhasebe';
      welcomeSender = 'Finans & Muhasebe Uzmanı';
      welcomeText =
          'Merhaba ${customer.name}, senet vadeleriniz, ödeme dekontlarınız ve hesap mutabakatınız için muhasebe birimimizle doğrudan buradan görüşebilirsiniz.';
    } else {
      subject = 'Genel Şirket Paneli • Yetkili Destek Hattı';
      category = 'Genel Şirket Paneli';
      welcomeSender = 'Demirtürk Yetkili Masası';
      welcomeText =
          'Merhaba ${customer.name}, mesajınız doğrudan genel şirket paneline iletilir. Müsait olan ilk yetkilimiz size anında yanıt verecektir.';
    }

    final created = SupportTicket(
      id: 'tck_${channel}_${customer.id}_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customer.id,
      subject: subject,
      category: category,
      channel: channel,
      isResolved: false,
      updatedAt: DateTime.now(),
      messages: [
        ChatMessage(
          id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
          isFromAdmin: true,
          senderName: welcomeSender,
          text: welcomeText,
          timestamp: DateTime.now(),
        ),
      ],
    );

    _tickets.insert(0, created);
    notifyListeners();
    return created;
  }

  // Customer or Admin action: Reply to a support ticket
  void sendTicketMessage({
    required String ticketId,
    required String text,
    required bool isFromAdmin,
    String? attachmentName,
  }) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;

    final ticket = _tickets[index];
    final customer = getCustomerById(ticket.customerId);
    final advisor = _salesAdvisors.firstWhere(
      (a) => a.id == customer.assignedAdvisorId,
      orElse: () => _salesAdvisors.first,
    );

    final String adminSenderName;
    if (ticket.channel == 'advisor') {
      adminSenderName = advisor.name;
    } else if (ticket.channel == 'finance') {
      adminSenderName = 'Finans & Muhasebe Uzmanı';
    } else {
      adminSenderName = 'Şirket Yetkilisi (Genel Panel)';
    }

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      isFromAdmin: isFromAdmin,
      senderName: isFromAdmin ? adminSenderName : customer.name,
      text: text,
      timestamp: DateTime.now(),
      attachmentName: attachmentName,
    );

    final updatedMessages = [...ticket.messages, newMessage];
    _tickets[index] = ticket.copyWith(
      updatedAt: DateTime.now(),
      messages: updatedMessages,
      isResolved: false,
    );

    if (isFromAdmin) {
      _notifications.insert(
        0,
        AppNotification(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          customerId: ticket.customerId,
          title: 'Şirket Yetkilisinden Yeni Yanıt',
          body: '"${ticket.subject}" konulu mesajınıza yanıt verildi: $text',
          createdAt: DateTime.now(),
          type: 'message',
        ),
      );
    }

    notifyListeners();
  }

  // Customer action: Create new support ticket
  SupportTicket createSupportTicket({
    required String subject,
    required String category,
    String? relatedSenetNo,
    required String initialMessage,
  }) {
    final customer = currentCustomer;
    final newTicket = SupportTicket(
      id: 'tck_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customer.id,
      subject: subject,
      category: category,
      relatedSenetNo: relatedSenetNo,
      isResolved: false,
      updatedAt: DateTime.now(),
      messages: [
        ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          isFromAdmin: false,
          senderName: customer.name,
          text: initialMessage,
          timestamp: DateTime.now(),
        ),
      ],
    );

    _tickets.insert(0, newTicket);
    notifyListeners();
    return newTicket;
  }

  void toggleTicketResolved(String ticketId) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;
    final ticket = _tickets[index];
    _tickets[index] = ticket.copyWith(isResolved: !ticket.isResolved);
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].customerId == _selectedCustomerId &&
          !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }
}
