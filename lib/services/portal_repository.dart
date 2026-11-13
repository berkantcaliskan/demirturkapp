import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/turkish_phone_input_formatter.dart';

/// Server backed operations for the customer/admin portal.
///
/// Rows are returned as JSON maps here; domain model mapping belongs in the
/// feature repository as the demo state is replaced screen by screen.
class PortalRepository {
  PortalRepository(this._client);

  final SupabaseClient _client;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> loadMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('profiles')
        .select('id, full_name, role, staff_role, staff_id, contact_phone')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> loadMyCustomer() async {
    final row = await _client
        .from('customers')
        .select()
        .maybeSingle(); // RLS limits this to the authenticated user's link.
    if (row == null) return null;
    return (await _attachCustomerRelations([row])).single;
  }

  Future<void> ensureMyCustomerRecord({String fullName = ''}) async {
    await _client.rpc(
      'ensure_my_customer_record',
      params: {'p_full_name': fullName},
    );
  }

  Future<List<Map<String, dynamic>>> loadCustomers() async {
    final rows = await _client
        .from('customers')
        .select()
        .order('created_at', ascending: false);
    final enrichedRows = await _attachCustomerRelations(rows);
    final pendingContracts = await _client
        .from('pending_contract_records')
        .select(
          'id, full_name, national_or_tax_id, phone, contract_number, assigned_advisor_id, folder_id, created_at',
        )
        .order('created_at', ascending: false);
    enrichedRows.addAll(
      pendingContracts.map(
        (row) => {
          'id': row['id'],
          'full_name': row['full_name'],
          'national_or_tax_id': row['national_or_tax_id'],
          'phone': row['phone'],
          'contract_number': row['contract_number'],
          'assigned_advisor_id': row['assigned_advisor_id'],
          'folder_id': row['folder_id'],
          'contract_status': 'pending',
          'email': '',
          'address': '',
        },
      ),
    );
    return enrichedRows;
  }

  Future<List<Map<String, dynamic>>> _attachCustomerRelations(
    List<Map<String, dynamic>> rows,
  ) async {
    final advisorIds = rows
        .map((row) => row['assigned_advisor_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final folderIds = rows
        .map((row) => row['folder_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final customerIds = rows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final relations = await Future.wait([
      advisorIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : _client
                .from('profiles')
                .select('id, full_name, staff_id, contact_phone')
                .inFilter('id', advisorIds),
      folderIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : _client
                .from('customer_folders')
                .select('id, name')
                .inFilter('id', folderIds),
      customerIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : _client
                .from('customer_contract_documents')
                .select('customer_id, storage_path, file_name, content_type')
                .inFilter('customer_id', customerIds),
    ]);
    final advisors = {
      for (final row in relations[0]) row['id'].toString(): row,
    };
    final folders = {for (final row in relations[1]) row['id'].toString(): row};
    final contractDocuments = {
      for (final row in relations[2]) row['customer_id'].toString(): row,
    };

    return rows.map((row) {
      final enriched = Map<String, dynamic>.from(row);
      enriched['advisor'] = advisors[row['assigned_advisor_id']?.toString()];
      enriched['folder'] = folders[row['folder_id']?.toString()];
      enriched['contract_document'] = contractDocuments[row['id']?.toString()];
      return enriched;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchCustomers() => _client
      .from('customers')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Future<List<Map<String, dynamic>>> loadSalesAdvisors() async => _client
      .from('profiles')
      .select('id, full_name, staff_id, contact_phone')
      .eq('staff_role', 'sales_advisor')
      .order('full_name');

  Future<List<Map<String, dynamic>>> loadPendingAccountLinks() async {
    final rows = await _client
        .from('customers')
        .select(
          'id, full_name, phone, contract_number, contract_status, auth_user_id',
        )
        .order('created_at', ascending: false);
    final contracts = <String, List<Map<String, dynamic>>>{};
    final accounts = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = normalizeTurkishPhoneNumber(row['phone']?.toString() ?? '');
      if (key == null) continue;
      if (row['auth_user_id'] == null && row['contract_number'] != null) {
        contracts.putIfAbsent(key, () => []).add({
          ...row,
          '_pending_contract_record': false,
        });
      } else if (row['auth_user_id'] != null && row['contract_number'] == null) {
        accounts.putIfAbsent(key, () => []).add(row);
      }
    }
    final pendingContracts = await _client
        .from('pending_contract_records')
        .select('id, full_name, phone, contract_number, created_at')
        .order('created_at', ascending: false);
    for (final contract in pendingContracts) {
      final key = normalizeTurkishPhoneNumber(
        contract['phone']?.toString() ?? '',
      );
      if (key == null) continue;
      contracts.putIfAbsent(key, () => []).add({
        ...contract,
        '_pending_contract_record': true,
      });
    }

    final matches = <Map<String, dynamic>>[];
    for (final entry in accounts.entries) {
      final matchingContracts = contracts[entry.key] ?? const [];
      if (entry.value.length != 1 || matchingContracts.length != 1) continue;
      matches.add({
        'account': entry.value.single,
        'contract': matchingContracts.single,
        'phone': entry.key,
      });
    }
    return matches;
  }

  Future<void> linkCustomerAccount({
    required String contractCustomerId,
    required String accountCustomerId,
  }) async {
    await _client.rpc(
      'link_customer_account',
      params: {
        'p_contract_customer_id': contractCustomerId,
        'p_account_customer_id': accountCustomerId,
      },
    );
  }

  Future<void> linkPendingContractAccount({
    required String pendingContractId,
    required String accountCustomerId,
  }) async {
    await _client.rpc(
      'link_pending_contract_account',
      params: {
        'p_pending_contract_id': pendingContractId,
        'p_account_customer_id': accountCustomerId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadCustomerFolders() async =>
      _client.from('customer_folders').select('id, name').order('name');

  Future<Map<String, dynamic>> createCustomerFolder(String name) async =>
      _client
          .from('customer_folders')
          .insert({'name': name.trim(), 'created_by': currentUserId})
          .select('id, name')
          .single();

  Future<void> assignCustomerFolder({
    required String customerId,
    String? folderId,
  }) async {
    await _client
        .from('customers')
        .update({'folder_id': folderId})
        .eq('id', customerId);
  }

  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String nationalOrTaxId,
    required String phone,
    required String assignedAdvisorId,
    required DateTime contractDate,
    required String contractFileName,
    required Uint8List contractFileBytes,
    required String contractContentType,
    String? folderId,
  }) async {
    if (contractFileBytes.isEmpty) {
      throw const FormatException('Sözleşme dosyası boş olamaz.');
    }
    final extension = contractFileName.split('.').last.toLowerCase();
    if (!const {'pdf', 'doc', 'docx'}.contains(extension)) {
      throw const FormatException('Sözleşme yalnızca PDF veya Word olabilir.');
    }
    if (!const {
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    }.contains(contractContentType)) {
      throw const FormatException('Bu sözleşme dosyası türü desteklenmiyor.');
    }
    final uploaderId = currentUserId;
    if (uploaderId == null) {
      throw const AuthException(
        'Sözleşme yüklemek için personel oturumu gerekli.',
      );
    }
    final safeName = contractFileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final objectPath =
        '$uploaderId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final storage = _client.storage.from('customer-contracts');
    await storage.uploadBinary(
      objectPath,
      contractFileBytes,
      fileOptions: FileOptions(contentType: contractContentType, upsert: false),
    );
    final normalizedPhone = _normalizeTurkishPhone(phone);
    final contractDateText =
        '${contractDate.year.toString().padLeft(4, '0')}-${contractDate.month.toString().padLeft(2, '0')}-${contractDate.day.toString().padLeft(2, '0')}';
    try {
      final customerId = await _client.rpc(
        'create_customer_with_contract',
        params: {
          'p_full_name': name.trim(),
          'p_national_or_tax_id': nationalOrTaxId.trim(),
          'p_phone': normalizedPhone,
          'p_assigned_advisor_id': assignedAdvisorId,
          'p_contract_date': contractDateText,
          'p_folder_id': folderId,
          'p_contract_storage_path': objectPath,
          'p_contract_file_name': contractFileName,
          'p_contract_content_type': contractContentType,
        },
      );
      return await _client
          .from('customers')
          .select()
          .eq('id', customerId.toString())
          .single();
    } catch (_) {
      try {
        await storage.remove([objectPath]);
      } catch (_) {
        // Preserve the original database error. The unique staged path can be
        // cleaned up later by a staff-only Storage policy if needed.
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createContract({
    required String name,
    required String nationalOrTaxId,
    required String phone,
    required String assignedAdvisorId,
    required DateTime contractDate,
    String? contractFileName,
    Uint8List? contractFileBytes,
    String? contractContentType,
    String? folderId,
  }) async {
    final hasFile = contractFileBytes != null && contractFileBytes.isNotEmpty;
    if (hasFile && (contractFileName == null || contractContentType == null)) {
      throw const FormatException('Sözleşme dosyası bilgisi eksik.');
    }
    final uploaderId = currentUserId;
    if (uploaderId == null) {
      throw const AuthException(
        'Sözleşme kaydetmek için personel oturumu gerekli.',
      );
    }
    String? objectPath;
    if (hasFile) {
      final extension = contractFileName!.split('.').last.toLowerCase();
      if (!const {'pdf', 'doc', 'docx'}.contains(extension)) {
        throw const FormatException(
          'Sözleşme yalnızca PDF veya Word olabilir.',
        );
      }
      if (!const {
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      }.contains(contractContentType)) {
        throw const FormatException('Bu sözleşme dosyası türü desteklenmiyor.');
      }
      final safeName = contractFileName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      objectPath =
          '$uploaderId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await _client.storage
          .from('customer-contracts')
          .uploadBinary(
            objectPath,
            contractFileBytes,
            fileOptions: FileOptions(
              contentType: contractContentType,
              upsert: false,
            ),
          );
    }
    final contractDateText =
        '${contractDate.year.toString().padLeft(4, '0')}-${contractDate.month.toString().padLeft(2, '0')}-${contractDate.day.toString().padLeft(2, '0')}';
    try {
      final customerId = await _client.rpc(
        'create_contract_record',
        params: {
          'p_full_name': name.trim(),
          'p_national_or_tax_id': nationalOrTaxId.trim(),
          'p_phone': _normalizeTurkishPhone(phone),
          'p_assigned_advisor_id': assignedAdvisorId,
          'p_contract_date': contractDateText,
          'p_folder_id': folderId,
          'p_contract_storage_path': objectPath,
          'p_contract_file_name': contractFileName,
          'p_contract_content_type': contractContentType,
        },
      );
      final rows = await _client
          .from('customers')
          .select()
          .eq('id', customerId.toString());
      if (rows.isNotEmpty) return rows.first;
      final pending = await _client
          .from('pending_contract_records')
          .select('contract_number')
          .eq('id', customerId.toString())
          .single();
      return pending;
    } catch (_) {
      if (objectPath != null) {
        try {
          await _client.storage.from('customer-contracts').remove([objectPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Uri> getContractDocumentUrl(String customerId) async {
    final document = await _client
        .from('customer_contract_documents')
        .select('storage_path')
        .eq('customer_id', customerId)
        .single();
    final url = await _client.storage
        .from('customer-contracts')
        .createSignedUrl(document['storage_path'].toString(), 600);
    return Uri.parse(url);
  }

  Future<List<Map<String, dynamic>>> loadMyNotes() async => _client
      .from('promissory_notes')
      .select('*, payment_submissions(*)')
      .order('due_date');

  Future<List<Map<String, dynamic>>> loadNotes() async => _client
      .from('promissory_notes')
      .select('*, payment_submissions(*)')
      .order('due_date');

  Stream<List<Map<String, dynamic>>> watchNotes() => _client
      .from('promissory_notes')
      .stream(primaryKey: ['id'])
      .order('due_date');

  Future<List<Map<String, dynamic>>> loadBankAccounts() async => _client
      .from('bank_accounts')
      .select()
      .eq('is_active', true)
      .order('sort_order');

  Future<void> reviewPaymentSubmission({
    required String noteId,
    required bool approved,
    String? rejectionReason,
    String? paymentMethod,
  }) async {
    final submissions = await _client
        .from('payment_submissions')
        .select('id')
        .eq('note_id', noteId)
        .eq('status', 'submitted')
        .order('submitted_at', ascending: false)
        .limit(1);
    if (submissions.isNotEmpty) {
      await _client
          .from('payment_submissions')
          .update({
            'status': approved ? 'approved' : 'rejected',
            'rejection_reason': rejectionReason,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'reviewed_by': currentUserId,
          })
          .eq('id', submissions.first['id']);
    } else {
      await _client
          .from('promissory_notes')
          .update({
            'status': approved ? 'paid' : 'pending',
            'paid_at': approved
                ? DateTime.now().toUtc().toIso8601String()
                : null,
            'payment_method': approved ? paymentMethod : null,
          })
          .eq('id', noteId);
      final note = await _client
          .from('promissory_notes')
          .select('customer_id, note_number')
          .eq('id', noteId)
          .single();
      await _client.from('notifications').insert({
        'customer_id': note['customer_id'],
        'title': approved ? 'Ödemeniz onaylandı' : 'Dekontunuz incelendi',
        'body': approved
            ? '${note['note_number']} numaralı senet ödemeniz onaylandı.'
            : rejectionReason ?? 'Ödeme bildiriminiz kabul edilmedi.',
        'type': approved ? 'approved' : 'rejected',
      });
    }
  }

  Future<void> sendPaymentReminder({
    required String customerId,
    required String noteNumber,
    required String dueDate,
    required String amountText,
  }) async {
    await _client.from('notifications').insert({
      'customer_id': customerId,
      'title': 'Şirket ödeme hatırlatması',
      'body':
          '$noteNumber numaralı, $dueDate vadeli $amountText tutarındaki senedinizin ödemesini hatırlatırız.',
      'type': 'reminder',
    });
  }

  Future<void> createInstallmentPlan({
    required String customerId,
    required double monthlyAmount,
    required int installmentCount,
    required DateTime firstDueDate,
    required String descriptionPrefix,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final rows = List.generate(installmentCount, (index) {
      final dueDate = DateTime(
        firstDueDate.year,
        firstDueDate.month + index,
        firstDueDate.day,
      );
      return {
        'customer_id': customerId,
        'note_number':
            'SNT-${DateTime.now().year}-${stamp.toString().substring(stamp.toString().length - 6)}-${(index + 1).toString().padLeft(2, '0')}',
        'installment_index': index + 1,
        'total_installments': installmentCount,
        'amount': monthlyAmount,
        'due_date': dueDate.toIso8601String().substring(0, 10),
        'description': '$descriptionPrefix - ${index + 1}. Taksit',
        'status': 'pending',
      };
    });
    await _client.from('promissory_notes').insert(rows);
  }

  Future<List<Map<String, dynamic>>> loadMyNotifications() async => _client
      .from('notifications')
      .select()
      .order('created_at', ascending: false);

  Stream<List<Map<String, dynamic>>> watchMyNotifications() => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  StreamSubscription<List<Map<String, dynamic>>> subscribeToMyNotifications(
    void Function(List<Map<String, dynamic>>) onData,
  ) => watchMyNotifications().listen(onData);

  Future<List<Map<String, dynamic>>> loadMyTickets() async => _client
      .from('support_tickets')
      .select(
        '*, ticket_messages(*), customer:customers(full_name, contract_number)',
      )
      .order('updated_at', ascending: false);

  Future<String> getOrCreateCustomerTicket(String channel) async {
    try {
      final ticketId = await _client.rpc(
        'get_or_create_customer_ticket',
        params: {'p_channel': channel},
      );
      return ticketId.toString();
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('henüz müşteri kaydıyla eşleştirilmedi')) {
        throw const AuthException(
          'Müşteri kaydınız henüz hesabınıza bağlanmadı. Destek için şirketle iletişime geçin.',
        );
      }
      if (message.contains('satış danışmanınız henüz atanmamış')) {
        throw const AuthException(
          'Satış danışmanınız henüz atanmamış. Şirket yetkilisiyle görüşebilirsiniz.',
        );
      }
      if (message.contains('muhasebe hesabı henüz tanımlanmamış')) {
        throw const AuthException(
          'Muhasebe ekibi henüz kullanıma açılmadı. Lütfen daha sonra tekrar deneyin.',
        );
      }
      throw const AuthException(
        'Sohbet başlatılamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }

  Stream<List<Map<String, dynamic>>> watchMyTickets() => _client
      .from('support_tickets')
      .stream(primaryKey: ['id'])
      .order('updated_at', ascending: false);

  Future<void> closeGeneralTicket(String ticketId) async =>
      _client.rpc('close_general_chat', params: {'ticket_id': ticketId});

  Future<void> deleteMyTicket(String ticketId) async =>
      _client.rpc('delete_my_chat', params: {'ticket_id': ticketId});

  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllMyNotificationsRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
  }

  Future<List<Map<String, dynamic>>> loadTicketMessages(
    String ticketId,
  ) async => _client
      .from('ticket_messages')
      .select()
      .eq('ticket_id', ticketId)
      .order('created_at');

  Stream<List<Map<String, dynamic>>> watchTicketMessages(String ticketId) =>
      _client
          .from('ticket_messages')
          .stream(primaryKey: ['id'])
          .eq('ticket_id', ticketId)
          .order('created_at');

  Future<void> sendTicketMessage({
    required String ticketId,
    required String body,
    String? attachmentObjectPath,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Sign in is required.');
    await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': userId,
      'body': body.trim().isEmpty ? 'Dosya eklendi' : body.trim(),
      'attachment_object_path': attachmentObjectPath,
    });
  }

  Future<String> uploadTicketAttachment({
    required String ticketId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('Sign in is required.');
    if (bytes.isEmpty) throw const FormatException('Dosya boş olamaz.');
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final objectPath =
        '$ticketId/$userId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from('message-attachments')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return objectPath;
  }

  Future<Uri> getTicketAttachmentUrl(String objectPath) async => Uri.parse(
    await _client.storage
        .from('message-attachments')
        .createSignedUrl(objectPath, 600),
  );

  Future<void> removeUnlinkedTicketAttachment(String objectPath) async {
    await _client.storage.from('message-attachments').remove([objectPath]);
  }

  Future<void> saveUserPreferences(Map<String, dynamic> settings) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Sign in is required.');
    await _client.from('user_preferences').upsert({
      'user_id': userId,
      'settings': settings,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> loadUserPreferences() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};
    final row = await _client
        .from('user_preferences')
        .select('settings')
        .eq('user_id', userId)
        .maybeSingle();
    return Map<String, dynamic>.from(row?['settings'] as Map? ?? const {});
  }

  /// Receipt files must be uploaded to the private Storage bucket first; only
  /// their object path is recorded in Postgres.
  Future<String> uploadPaymentReceipt({
    required String customerId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final objectPath =
        '$customerId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from('payment-receipts')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return objectPath;
  }

  Future<void> deletePaymentReceipt(String objectPath) async {
    await _client.storage.from('payment-receipts').remove([objectPath]);
  }

  Future<Uri> getPaymentReceiptUrl(String objectPath) async => Uri.parse(
    await _client.storage
        .from('payment-receipts')
        .createSignedUrl(objectPath, 600),
  );

  Future<void> submitPaymentReceipt({
    required String noteId,
    required String customerId,
    required String receiptObjectPath,
    required String paymentMethod,
    String? customerNote,
  }) async {
    await _client.from('payment_submissions').insert({
      'note_id': noteId,
      'customer_id': customerId,
      'receipt_object_path': receiptObjectPath,
      'payment_method': paymentMethod,
      'customer_note': customerNote,
    });
  }
}

String _normalizeTurkishPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('90') && digits.length == 12) return '+$digits';
  if (digits.startsWith('0') && digits.length == 11) {
    return '+90${digits.substring(1)}';
  }
  if (digits.length == 10) return '+90$digits';
  return value.trim();
}
