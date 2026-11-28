import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/turkish_phone_input_formatter.dart';
import 'upload_policy.dart';

/// Server backed operations for the customer/admin portal.
///
/// Rows are returned as JSON maps here; domain model mapping belongs in the
/// feature repository as the demo state is replaced screen by screen.
class PortalRepository {
  PortalRepository(this._client, {this.staffNotifications = false});

  final SupabaseClient _client;
  final bool staffNotifications;
  String get _notificationsTable =>
      staffNotifications ? 'staff_notifications' : 'notifications';
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> loadFinanceSnapshots() async {
    try {
      return await _allRows((start, end) => _client.from('customer_finance_snapshots')
          .select('customer_id,snapshot,imported_at').order('customer_id').range(start, end));
    } on PostgrestException catch (error) {
      if (['42P01', 'PGRST205'].contains(error.code)) return [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _financeAction(Map<String, dynamic> body) async {
    try {
      final result = await _client.functions.invoke('crm-finance', body: body);
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (error) {
      final code = error.details is Map ? (error.details as Map)['error'] : null;
      throw FormatException(switch (code) {
        'finance_forbidden' => 'Bu müşterinin ödeme bilgilerine erişiminiz yok.',
        'finance_plan_already_linked' => 'Bu sözleşme başka bir müşteriyle eşleştirilmiş.',
        'finance_reconciliation_required' => 'CRM’de tahsilatların ilgili senetlerle eşleştirilmesi gerekiyor.',
        'finance_unbalanced_plan' => 'CRM ödeme planı toplamıyla sözleşme tutarı uyuşmuyor. Muhasebe kontrolü gerekiyor.',
        'finance_overpayment' => 'CRM tahsilat toplamı kontrol edilmeli. Son doğrulanmış bilgiler korunuyor.',
        'finance_setup_pending' => 'CRM bağlantısı henüz etkinleştirilmedi.',
        'finance_link_changed' => 'Hesap eşleştirmesi değişti. Ödemeleri yeniden yenileyin.',
        _ => 'Ödeme bilgileri şu an yenilenemiyor. Son doğrulanmış bilgiler gösteriliyor.',
      });
    }
  }

  Future<void> syncCustomerFinance(String customerId) async {
    // Existing accounts without a CRM link continue using their current payment flow.
    try {
      final links = await _client.from('crm_finance_links').select('customer_id').eq('customer_id', customerId).limit(1);
      if (links.isEmpty) return;
    } on PostgrestException catch (error) {
      if (['42P01', 'PGRST205'].contains(error.code)) return;
      rethrow;
    }
    await _financeAction({'action': 'sync', 'customerId': customerId});
  }

  Future<Map<String, dynamic>> searchCrmFinancePlans(String query, {String after = ''}) =>
      _financeAction({'action': 'search', 'query': query, 'after': after});

  Future<List<String>> loadCrmLinkedPlanIds(String customerId) async {
    final result = await _client.rpc('portal_crm_finance_context', params: {'p_customer_id': customerId});
    return result == null ? [] : List<String>.from((result as Map)['planIds'] as List);
  }

  Future<void> linkCrmFinancePlans(String customerId, List<String> planIds) async {
    await _financeAction({'action': planIds.isEmpty ? 'unlink' : 'link', 'customerId': customerId, 'planIds': planIds});
  }

  Future<List<Map<String, dynamic>>> _allRows(
    Future<List<Map<String, dynamic>>> Function(int start, int end) page,
  ) async {
    const pageSize = 200;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      final next = await page(offset, offset + pageSize - 1);
      rows.addAll(next);
      if (next.length < pageSize) return rows;
    }
  }

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
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('customers')
        .select()
        .eq('auth_user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return (await _attachCustomerRelations([row])).single;
  }

  Future<void> ensureMyCustomerRecord({String fullName = ''}) async {
    await _client.rpc(
      'ensure_my_customer_record',
      params: {'p_full_name': fullName},
    );
  }

  Future<List<Map<String, dynamic>>> loadCustomers({String? advisorId}) async {
    final query = _client.from('customers').select().eq('is_demo', false);
    final rows = await _allRows((start, end) => (advisorId == null
                ? query
                : query.eq('assigned_advisor_id', advisorId))
            .order('created_at', ascending: false).order('id').range(start, end));
    final enrichedRows = await _attachCustomerRelations(rows);
    if (advisorId != null) return enrichedRows;
    final pendingContracts = await _allRows((start, end) => _client
        .from('pending_contract_records')
        .select(
          'id, full_name, national_or_tax_id, phone, contract_number, assigned_advisor_id, project_name, unit_label, storage_path, file_name',
        )
        .order('created_at', ascending: false).order('id').range(start, end));
    enrichedRows.addAll(
      pendingContracts.map(
        (row) => {
          'id': row['id'],
          'full_name': row['full_name'],
          'national_or_tax_id': row['national_or_tax_id'],
          'phone': row['phone'],
          'contract_number': row['contract_number'],
          'assigned_advisor_id': row['assigned_advisor_id'],
          'project_name': row['project_name'],
          'unit_label': row['unit_label'],
          'is_pending_contract_record': true,
          if (row['storage_path'] != null)
            'contract_document': {
              'storage_path': row['storage_path'],
              'file_name': row['file_name'],
            },
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
    final customerIds = rows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    Future<List<Map<String, dynamic>>> related(String table, String columns,
        String key, List<String> ids) async {
      final result = <Map<String, dynamic>>[];
      for (var offset = 0; offset < ids.length; offset += 100) {
        final end = (offset + 100).clamp(0, ids.length);
        result.addAll(await _allRows((start, endRow) => _client.from(table)
          .select(columns).inFilter(key, ids.sublist(offset, end))
          .order(key).order(table == 'customer_folder_memberships' ? 'owner_id' : key)
          .range(start, endRow)));
      }
      return result;
    }
    final relations = await Future.wait([
      related('profiles', 'id, full_name, staff_id, contact_phone', 'id', advisorIds),
      related('customer_folder_memberships', 'customer_id, folder_id, owner_id', 'customer_id', customerIds),
      related('customer_contract_documents', 'customer_id, storage_path, file_name, content_type', 'customer_id', customerIds),
    ]);
    final advisors = {
      for (final row in relations[0]) row['id'].toString(): row,
    };
    final folders = <String, List<Map<String, dynamic>>>{};
    for (final row in relations[1]) {
      folders.putIfAbsent(row['customer_id'].toString(), () => []).add(row);
    }
    final contractDocuments = {
      for (final row in relations[2]) row['customer_id'].toString(): row,
    };

    return rows.map((row) {
      final enriched = Map<String, dynamic>.from(row);
      enriched['advisor'] = advisors[row['assigned_advisor_id']?.toString()];
      enriched['folder_memberships'] = folders[row['id']?.toString()] ?? [];
      enriched['contract_document'] = contractDocuments[row['id']?.toString()];
      return enriched;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchCustomers() => _client
      .from('customers')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Stream<List<Map<String, dynamic>>> watchMyCustomer() => _client
      .from('customers')
      .stream(primaryKey: ['id'])
      .eq('auth_user_id', currentUserId!);

  Future<List<Map<String, dynamic>>> loadSalesAdvisors() async => _client
      .from('profiles')
      .select('id, full_name, staff_id, contact_phone')
      .eq('staff_role', 'sales_advisor')
      .order('full_name');

  Future<List<Map<String, dynamic>>> loadPendingAccountLinks() async {
    final rows = await _client
        .from('customers')
        .select(
          'id, full_name, phone, contract_number, contract_status, auth_user_id, customer_contract_documents(customer_id)',
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
      } else if (row['auth_user_id'] != null &&
          row['contract_number'] == null) {
        accounts.putIfAbsent(key, () => []).add(row);
      }
    }
    final pendingContracts = await _client
        .from('pending_contract_records')
        .select('id, full_name, phone, contract_number, storage_path')
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

  Future<List<Map<String, dynamic>>> loadCustomerFolders({
    String? ownerId,
  }) async {
    final query = _client
        .from('customer_folders')
        .select('id, name, created_by, profiles(full_name)');
    return (ownerId == null ? query : query.eq('created_by', ownerId)).order(
      'name',
    );
  }

  Future<List<Map<String, dynamic>>> listPortalAccounts() async =>
      List<Map<String, dynamic>>.from(
        await _client.rpc('list_portal_accounts'),
      );

  Future<List<Map<String, dynamic>>> listDelegatedTickets(
    String accountId,
  ) async => List<Map<String, dynamic>>.from(
    await _client.rpc(
      'list_delegated_portal_tickets',
      params: {'p_account_id': accountId},
    ),
  );

  Future<List<Map<String, dynamic>>> loadPendingPaymentReviews() async =>
      _client
          .from('payment_submissions')
          .select(
            'id, receipt_object_path, customers(full_name), promissory_notes(note_number)',
          )
          .eq('status', 'submitted')
          .order('submitted_at');

  Future<void> performPortalAccountAction(
    String accountId,
    String action,
    Map<String, dynamic> payload,
  ) async {
    await _client.rpc(
      'perform_portal_account_action',
      params: {
        'p_account_id': accountId,
        'p_action': action,
        'p_payload': payload,
      },
    );
  }

  Future<Map<String, dynamic>?> loadCustomerForPreview(
    String id, {
    bool byAccount = false,
    String? advisorId,
  }) async {
    final query = _client
        .from('customers')
        .select()
        .eq(byAccount ? 'auth_user_id' : 'id', id);
    final row =
        await (advisorId == null
                ? query
                : query.eq('assigned_advisor_id', advisorId))
            .maybeSingle();
    if (row == null) return null;
    return (await _attachCustomerRelations([row])).single;
  }

  Future<List<Map<String, dynamic>>> loadNotesForCustomer(
    String customerId,
  ) async => _allRows((start, end) => _client
      .from('promissory_notes')
      .select('*, payment_submissions(*)')
      .eq('customer_id', customerId)
      .order('due_date').order('id').range(start, end));

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
    await _client.rpc(
      'assign_customer_to_portal_folder',
      params: {'p_customer_id': customerId, 'p_folder_id': folderId},
    );
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
    required String projectName,
    required String unitLabel,
    String? contractFileName,
    Uint8List? contractFileBytes,
    String? contractContentType,
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
      UploadPolicy.validateSize(contractFileBytes.length, UploadPolicy.contractBytes);
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
      final contractNumber = await _client.rpc(
        'create_portal_contract',
        params: {
          'p_full_name': name.trim(),
          'p_national_or_tax_id': nationalOrTaxId.trim(),
          'p_phone': _normalizeTurkishPhone(phone),
          'p_assigned_advisor_id': assignedAdvisorId,
          'p_contract_date': contractDateText,
          'p_project_name': projectName.trim(),
          'p_unit_label': unitLabel.trim(),
          'p_contract_storage_path': objectPath,
          'p_contract_file_name': contractFileName,
          'p_contract_content_type': contractContentType,
        },
      );
      return {'contract_number': contractNumber};
    } catch (_) {
      if (objectPath != null) {
        try {
          await _client.storage.from('customer-contracts').remove([objectPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> attachPendingContractDocument({required String contractId,
    required String fileName, required Uint8List bytes}) async {
    UploadPolicy.validateSize(bytes.length, UploadPolicy.contractBytes);
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => throw const FormatException('Sözleşme yalnızca PDF veya Word olabilir.'),
    };
    final userId = currentUserId;
    if (userId == null) throw const AuthException('Oturum açmanız gerekiyor.');
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final storage = _client.storage.from('customer-contracts');
    await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    try {
      await _client.rpc('attach_pending_contract_document', params: {
        'p_contract_id': contractId, 'p_storage_path': path,
        'p_file_name': fileName, 'p_content_type': contentType,
      });
    } catch (_) {
      try { await storage.remove([path]); } catch (_) {}
      rethrow;
    }
  }

  Future<Uri> getContractDocumentUrl(
    String customerId, {
    bool pending = false,
  }) async {
    final document = await _client
        .from(
          pending ? 'pending_contract_records' : 'customer_contract_documents',
        )
        .select('storage_path')
        .eq(pending ? 'id' : 'customer_id', customerId)
        .single();
    final path = document['storage_path'] as String?;
    if (path == null || path.isEmpty) {
      throw const FormatException('Sözleşme dosyası bulunamadı.');
    }
    final url = await _client.storage
        .from('customer-contracts')
        .createSignedUrl(path, 600);
    return Uri.parse(url);
  }

  Future<List<Map<String, dynamic>>> loadMyNotes() => _allRows((start, end) => _client
      .from('promissory_notes')
      .select('*, payment_submissions(*)')
      .order('due_date').order('id').range(start, end));

  Future<List<Map<String, dynamic>>> loadNotes() async => _allRows((start, end) => _client
      .from('promissory_notes')
      .select('*, payment_submissions(*), customers!inner(is_demo)')
      .eq('customers.is_demo', false)
      .order('due_date').order('id').range(start, end));

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
    if (approved) {
      final note = await _client.from('promissory_notes').select().eq('id', noteId).single();
      if (note['crm_plan_id'] != null) {
        throw const FormatException('Tahsilatı e-Demirtürk’te kaydedip ödeme bilgilerini yenileyin.');
      }
    }
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

  Future<List<Map<String, dynamic>>> loadMyNotifications() async => _allRows((start, end) => _client
      .from(_notificationsTable)
      .select()
      .order('created_at', ascending: false).order('id').range(start, end));

  Stream<List<Map<String, dynamic>>> watchMyNotifications() => _client
      .from(_notificationsTable)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .asyncMap((_) => loadMyNotifications());

  StreamSubscription<List<Map<String, dynamic>>> subscribeToMyNotifications(
    void Function(List<Map<String, dynamic>>) onData,
  ) => watchMyNotifications().listen(onData);

  Future<List<Map<String, dynamic>>> loadMyTickets() async => _allRows((start, end) => _client
      .from('support_tickets')
      .select(
        '*, ticket_messages(*), customer:customers(full_name, contract_number)',
      )
      .order('created_at', referencedTable: 'ticket_messages', ascending: false)
      .limit(1, referencedTable: 'ticket_messages')
      .order('updated_at', ascending: false).order('id').range(start, end));

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
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllMyNotificationsRead() async {
    await _client
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('is_read', false);
  }

  Future<List<Map<String, dynamic>>> loadTicketMessages(
    String ticketId,
  ) async => _allRows((start, end) => _client
      .from('ticket_messages')
      .select()
      .eq('ticket_id', ticketId)
      .order('created_at').order('id').range(start, end));

  Stream<List<Map<String, dynamic>>> watchTicketMessages(String ticketId) =>
      _client
          .from('ticket_messages')
          .stream(primaryKey: ['id'])
          .eq('ticket_id', ticketId)
          .order('created_at')
          .asyncMap((_) => loadTicketMessages(ticketId));

  Future<void> sendTicketMessage({
    required String ticketId,
    required String body,
    String? attachmentObjectPath,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Sign in is required.');
    if (body.trim().length > UploadPolicy.messageCharacters) {
      throw const FormatException('Mesaj en fazla 4000 karakter olabilir.');
    }
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
    UploadPolicy.validateSize(bytes.length, UploadPolicy.attachmentBytes);
    UploadPolicy.validateAttachmentName(fileName);
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
    UploadPolicy.validateSize(bytes.length, UploadPolicy.receiptBytes);
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
