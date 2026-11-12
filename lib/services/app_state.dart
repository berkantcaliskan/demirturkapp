import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  UserRole _currentRole = UserRole.customer;
  String _selectedCustomerId = '';
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasRemoteNotifications = false;
  String? _localStaffName;

  UserRole get currentRole => _currentRole;
  String get selectedCustomerId => _selectedCustomerId;
  ThemeMode get themeMode => _themeMode;
  String? get localStaffName => _localStaffName;

  void setLocalStaffName(String value) {
    _localStaffName = value.trim();
    notifyListeners();
  }

  void clearLocalStaffName() {
    if (_localStaffName == null) return;
    _localStaffName = null;
    notifyListeners();
  }

  void clearSessionData() {
    _selectedCustomerId = '';
    _hasRemoteNotifications = false;
    _localStaffName = null;
    _bankAccounts.clear();
    _salesAdvisors.clear();
    _customers.clear();
    _notes.clear();
    _tickets.clear();
    _notifications.clear();
    notifyListeners();
  }

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleThemeMode(BuildContext context) {
    final currentlyDark = isDark(context);
    _themeMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Customer get currentCustomer =>
      _customers
          .where((customer) => customer.id == _selectedCustomerId)
          .firstOrNull ??
      _emptyCustomer;

  static const Customer _emptyCustomer = Customer(
    id: '',
    name: '',
    tcOrTaxNo: '',
    phone: '',
    email: '',
    address: '',
    contractNo: '',
    assignedAdvisorId: '',
    contractStatus: 'pending',
    projectName: '',
    unitLabel: '',
    projectStatus: '',
  );

  static final SalesAdvisor _unassignedAdvisor = SalesAdvisor(
    id: '',
    name: 'Henüz atanmadı',
    roleTitle: 'Satış danışmanı',
    phone: '',
    photoUrl: '',
    photoUpdatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  SalesAdvisor get currentSalesAdvisor =>
      _salesAdvisors
          .where((advisor) => advisor.id == currentCustomer.assignedAdvisorId)
          .firstOrNull ??
      _unassignedAdvisor;

  List<SalesAdvisor> get salesAdvisors => List.unmodifiable(_salesAdvisors);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<PromissoryNote> get allNotes => List.unmodifiable(_notes);
  List<BankAccount> get bankAccounts => List.unmodifiable(_bankAccounts);
  List<SupportTicket> get allTickets => List.unmodifiable(_tickets);

  List<PromissoryNote> get customerNotes =>
      _notes.where((n) => n.customerId == _selectedCustomerId).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<SupportTicket> get customerTickets =>
      _tickets
          .where(
            (t) =>
                t.customerId == _selectedCustomerId &&
                !(t.isEndedByCustomer &&
                    t.channel != 'advisor' &&
                    t.channel != 'finance'),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<AppNotification> get customerNotifications =>
      _notifications
          .where(
            (n) =>
                _hasRemoteNotifications || n.customerId == _selectedCustomerId,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadNotificationCount =>
      customerNotifications.where((n) => !n.isRead).length;

  void replaceCustomerNotifications(List<Map<String, dynamic>> rows) {
    final parsed = rows
        .map(
          (row) => AppNotification(
            id: row['id'].toString(),
            customerId: row['customer_id'].toString(),
            title: row['title'] as String? ?? 'Bildirim',
            body: row['body'] as String? ?? '',
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '')
                    ?.toLocal() ??
                DateTime.now(),
            isRead: row['is_read'] as bool? ?? false,
            type: row['type'] as String? ?? 'general',
          ),
        )
        .toList();
    _hasRemoteNotifications = true;
    _notifications
      ..clear()
      ..addAll(parsed);
    notifyListeners();
  }

  int get pendingVerificationCount =>
      _notes.where((n) => n.status == NoteStatus.verifying).length;

  List<BankAccount> _bankAccounts = [];

  final List<SalesAdvisor> _salesAdvisors = [];

  final List<Customer> _customers = [];

  final List<PromissoryNote> _notes = [];

  final List<SupportTicket> _tickets = [];

  final List<AppNotification> _notifications = [];

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void replaceBackendCustomerData({
    required Map<String, dynamic> customerRow,
    required List<Map<String, dynamic>> noteRows,
    required List<Map<String, dynamic>> bankRows,
  }) {
    final customer = _customerFromRow(customerRow);
    _customers
      ..clear()
      ..add(customer);
    _selectedCustomerId = customer.id;
    _notes
      ..clear()
      ..addAll(noteRows.map(_noteFromRow));
    _replaceBankAccounts(bankRows);
    final advisorName = customerRow['assigned_advisor_name']?.toString();
    final advisorRow = customerRow['advisor'];
    if (advisorRow is Map) {
      _salesAdvisors
        ..clear()
        ..add(_salesAdvisorFromRow(advisorRow));
    } else if (advisorName != null && advisorName.trim().isNotEmpty) {
      _salesAdvisors
        ..clear()
        ..add(_unassignedAdvisor.copyWith(name: advisorName.trim()));
    }
    notifyListeners();
  }

  void replaceBackendPendingCustomer({
    required String name,
    required String phone,
    required List<Map<String, dynamic>> bankRows,
  }) {
    const pendingId = 'pending_customer_profile';
    _customers
      ..clear()
      ..add(
        Customer(
          id: pendingId,
          name: name.trim().isEmpty ? 'Müşteri' : name.trim(),
          tcOrTaxNo: '',
          phone: phone,
          email: '',
          address: '',
          contractNo: '',
          assignedAdvisorId: '',
          contractStatus: 'pending',
          projectName: '',
          unitLabel: '',
          projectStatus: '',
        ),
      );
    _selectedCustomerId = pendingId;
    _notes.clear();
    _tickets.clear();
    _notifications.clear();
    _replaceBankAccounts(bankRows);
    notifyListeners();
  }

  void replaceBackendAdminData({
    required List<Map<String, dynamic>> customerRows,
    required List<Map<String, dynamic>> noteRows,
    required List<Map<String, dynamic>> bankRows,
  }) {
    _customers
      ..clear()
      ..addAll(customerRows.map(_customerFromRow));
    _notes
      ..clear()
      ..addAll(noteRows.map(_noteFromRow));
    _replaceBankAccounts(bankRows);
    _replaceSalesAdvisorsFromCustomers(customerRows);
    if (_customers.isNotEmpty &&
        !_customers.any((customer) => customer.id == _selectedCustomerId)) {
      _selectedCustomerId = _customers.first.id;
    }
    notifyListeners();
  }

  void replaceBackendNotes(List<Map<String, dynamic>> rows) {
    _notes
      ..clear()
      ..addAll(rows.map(_noteFromRow));
    notifyListeners();
  }

  void replaceBackendCustomers(List<Map<String, dynamic>> rows) {
    _customers
      ..clear()
      ..addAll(rows.map(_customerFromRow));
    _replaceSalesAdvisorsFromCustomers(rows);
    if (_customers.isNotEmpty &&
        !_customers.any((customer) => customer.id == _selectedCustomerId)) {
      _selectedCustomerId = _customers.first.id;
    }
    notifyListeners();
  }

  void _replaceSalesAdvisorsFromCustomers(
    List<Map<String, dynamic>> customerRows,
  ) {
    final advisors = <String, SalesAdvisor>{};
    for (final row in customerRows) {
      final advisor = row['advisor'];
      if (advisor is Map && advisor['id'] != null) {
        final parsed = _salesAdvisorFromRow(advisor);
        advisors[parsed.id] = parsed;
      }
    }
    _salesAdvisors
      ..clear()
      ..addAll(advisors.values);
  }

  SalesAdvisor _salesAdvisorFromRow(Map advisor) => SalesAdvisor(
    id: advisor['id']?.toString() ?? '',
    name: advisor['full_name']?.toString() ?? 'Satış danışmanı',
    roleTitle: 'Satış Danışmanı',
    phone: advisor['contact_phone']?.toString() ?? '',
    photoUrl: advisor['photo_url']?.toString() ?? '',
    photoUpdatedAt:
        DateTime.tryParse(advisor['photo_updated_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  void _replaceBankAccounts(List<Map<String, dynamic>> rows) {
    _bankAccounts = rows.map((row) {
      final name = row['bank_name']?.toString() ?? '';
      final color = name.toLowerCase().contains('ziraat')
          ? const Color(0xFFE11D48)
          : name.toLowerCase().contains('garanti')
          ? const Color(0xFF059669)
          : const Color(0xFF1D4ED8);
      return BankAccount(
        bankName: name,
        accountHolder: row['account_holder']?.toString() ?? '',
        iban: row['iban']?.toString() ?? '',
        branchName: row['branch_name']?.toString() ?? '',
        brandColor: color,
      );
    }).toList();
  }

  Customer _customerFromRow(Map<String, dynamic> row) => Customer(
    id: row['id'].toString(),
    name: row['full_name']?.toString() ?? '',
    tcOrTaxNo: row['national_or_tax_id']?.toString() ?? '',
    phone: row['phone']?.toString() ?? '',
    email: row['email']?.toString() ?? '',
    address: row['address']?.toString() ?? '',
    contractNo: row['contract_number']?.toString() ?? '',
    assignedAdvisorId: row['assigned_advisor_id']?.toString() ?? '',
    projectName: row['project_name']?.toString(),
    unitLabel: row['unit_label']?.toString(),
    projectStatus: row['project_status']?.toString(),
    contractStatus: row['contract_status']?.toString() ?? 'approved',
    folderId: row['folder_id']?.toString(),
    folderName:
        (row['folder'] as Map?)?['name']?.toString() ??
        row['folder_name']?.toString(),
    contractDocumentPath: (row['contract_document'] as Map?)?['storage_path']
        ?.toString(),
    contractDocumentName: (row['contract_document'] as Map?)?['file_name']
        ?.toString(),
  );

  PromissoryNote _noteFromRow(Map<String, dynamic> row) {
    final submissions =
        (row['payment_submissions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort(
            (a, b) => (b['submitted_at']?.toString() ?? '').compareTo(
              a['submitted_at']?.toString() ?? '',
            ),
          );
    final Map<String, dynamic>? submission = submissions.isEmpty
        ? null
        : submissions.first;
    final receiptPath = submission?['receipt_object_path']?.toString();
    return PromissoryNote(
      id: row['id'].toString(),
      customerId: row['customer_id'].toString(),
      senetNo: row['note_number']?.toString() ?? '',
      installmentIndex: (row['installment_index'] as num?)?.toInt() ?? 1,
      totalInstallments: (row['total_installments'] as num?)?.toInt() ?? 1,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      dueDate:
          DateTime.tryParse(row['due_date']?.toString() ?? '') ??
          DateTime.now(),
      paidDate: DateTime.tryParse(row['paid_at']?.toString() ?? ''),
      status: NoteStatus.values.firstWhere(
        (status) => status.name == row['status']?.toString(),
        orElse: () => NoteStatus.pending,
      ),
      description: row['description']?.toString() ?? '',
      receiptFileName: receiptPath?.split('/').last,
      receiptObjectPath: receiptPath,
      receiptNote: submission?['customer_note']?.toString(),
      submittedAt: DateTime.tryParse(
        submission?['submitted_at']?.toString() ?? '',
      ),
      paymentMethod: row['payment_method']?.toString(),
      rejectionReason: submission?['rejection_reason']?.toString(),
    );
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
          (n) => n.customerId == customerId && n.status == NoteStatus.overdue,
        )
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
    return _customers.where((customer) => customer.id == id).firstOrNull ??
        _emptyCustomer;
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
      (t) =>
          t.customerId == customer.id &&
          t.channel == channel &&
          !t.isEndedByCustomer,
    );
    if (existingIndex != -1) {
      return _tickets[existingIndex];
    }

    final advisor = currentSalesAdvisor;
    final String subject;
    final String category;

    if (channel == 'advisor') {
      subject = advisor.firstName;
      category = 'Satış Danışmanım';
    } else if (channel == 'finance') {
      subject = 'Finans Uzmanımız';
      category = 'Finans & Muhasebe';
    } else {
      subject = 'Yetkili Görüşmesi';
      category = 'Genel Mesajlaşma';
    }

    final created = SupportTicket(
      id: 'tck_${channel}_${customer.id}_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customer.id,
      subject: subject,
      category: category,
      channel: channel,
      isResolved: false,
      isEndedByCustomer: false,
      updatedAt: DateTime.now(),
      messages: const [],
    );

    _tickets.insert(0, created);
    notifyListeners();
    return created;
  }

  // Satış danışmanı ve muhasebe dışındaki sohbetlerde "Sohbeti Bitir" dendiğinde müşteride kaybolur, şirkette depolanır
  void endCustomerChat(String ticketId) {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;
    final ticket = _tickets[index];
    if (ticket.channel == 'advisor' || ticket.channel == 'finance') return;

    if (ticket.messages.isEmpty) {
      _tickets.removeAt(index);
    } else {
      _tickets[index] = ticket.copyWith(
        isEndedByCustomer: true,
        isResolved: true,
      );
    }
    notifyListeners();
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
    final advisor =
        _salesAdvisors
            .where((a) => a.id == customer.assignedAdvisorId)
            .firstOrNull ??
        _unassignedAdvisor;

    final String adminSenderName;
    if (ticket.channel == 'advisor') {
      adminSenderName = advisor.firstName;
    } else if (ticket.channel == 'finance') {
      adminSenderName = 'Finans Uzmanı';
    } else {
      adminSenderName = 'Yetkili';
    }

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      isFromAdmin: isFromAdmin,
      senderName: isFromAdmin ? adminSenderName : customer.firstName,
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
