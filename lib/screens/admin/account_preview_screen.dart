import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/portal_repository.dart';
import '../../widgets/contract_document_button.dart';
import '../customer/customer_contract_card.dart';
import '../customer/customer_home_screen.dart';
import '../customer/customer_notes_screen.dart';
import '../customer/customer_project_screen.dart';
import '../customer/customer_project_showcase.dart';
import 'admin_dashboard_screen.dart';
import 'delegated_account_actions.dart';

class CustomerPreviewScreen extends StatefulWidget {
  const CustomerPreviewScreen({
    super.key,
    required this.repository,
    required this.id,
    this.byAccount = false,
    this.advisorId,
  });

  final PortalRepository repository;
  final String id;
  final bool byAccount;
  final String? advisorId;

  @override
  State<CustomerPreviewScreen> createState() => _CustomerPreviewScreenState();
}

class _CustomerPreviewScreenState extends State<CustomerPreviewScreen> {
  final AppState _preview = AppState();
  late Future<bool> _ready = _load();
  int _tab = 0;

  Future<bool> _load() async {
    final repository = widget.repository;
    final row = await repository.loadCustomerForPreview(
      widget.id,
      byAccount: widget.byAccount,
      advisorId: widget.advisorId,
    );
    if (row == null || !mounted) return false;
    final results = await Future.wait([
      if (widget.advisorId == null)
        repository.loadNotesForCustomer(row['id'].toString())
      else
        Future.value(<Map<String, dynamic>>[]),
      repository.loadBankAccounts(),
    ]);
    if (!mounted) return false;
    _preview.replaceBackendCustomerData(
      customerRow: row,
      noteRows: results[0],
      bankRows: results[1],
    );
    return true;
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Müşteri ekranı'),
      actions: [
        if (widget.byAccount)
          IconButton(
            tooltip: 'Bu hesap adına sohbet et',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DelegatedConversationsScreen(
                  repository: widget.repository,
                  accountId: widget.id,
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Personel ekranına dön',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ],
    ),
    body: FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _ready = _load()),
              child: const Text('Müşteri ekranını yeniden yükle'),
            ),
          );
        }
        if (snapshot.data != true)
          return const Center(child: Text('Müşteri kaydı bulunamadı.'));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_preview.currentCustomer.name} · ${widget.byAccount ? 'Hesap adına' : 'Önizleme'}',
              ),
            ),
            Expanded(child: _buildTab()),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (tab) => setState(() => _tab = tab),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Başlangıç',
                ),
                if (widget.advisorId == null)
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: 'Ödemelerim',
                  ),
                if (widget.advisorId == null)
                  const NavigationDestination(
                    icon: Icon(Icons.apartment),
                    label: 'Evim',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: 'Sözleşmelerim',
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _buildTab() =>
      switch (widget.advisorId != null && _tab > 0 ? 3 : _tab) {
        0 =>
          _preview.currentCustomer.contractNo.isEmpty
              ? const CustomerProjectShowcase(bottomPadding: 0)
              : widget.advisorId != null
              ? CustomerProjectScreen(
                  appState: _preview,
                  repository: widget.repository,
                )
              : CustomerHomeScreen(
                  appState: _preview,
                  readOnly: true,
                  onNavigateTab: (_) => setState(() => _tab = 1),
                ),
        1 => CustomerNotesScreen(appState: _preview, readOnly: true),
        2 => CustomerProjectScreen(
          appState: _preview,
          repository: widget.repository,
        ),
        _ => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomerContractCard(
              customer: _preview.currentCustomer,
              repository: widget.repository,
            ),
          ],
        ),
      };
}

class PortalAccountsScreen extends StatefulWidget {
  const PortalAccountsScreen({super.key, required this.repository});

  final PortalRepository repository;

  @override
  State<PortalAccountsScreen> createState() => _PortalAccountsScreenState();
}

class _PortalAccountsScreenState extends State<PortalAccountsScreen> {
  late Future<List<Map<String, dynamic>>> _accounts = widget.repository
      .listPortalAccounts();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Diğer hesaplar')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _accounts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _accounts = widget.repository.listPortalAccounts(),
              ),
              child: const Text('Hesap listesini yeniden yükle'),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final accounts = snapshot.data!;
        if (accounts.isEmpty)
          return const Center(child: Text('Başka hesap bulunamadı.'));
        return ListView.builder(
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            final role = switch (account['staff_role']) {
              'sales_advisor' => 'Satış danışmanı',
              'accounting' => 'Muhasebe',
              'management' => 'Yönetim',
              _ => 'Müşteri',
            };
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                (account['full_name'] as String?)?.trim().isNotEmpty == true
                    ? account['full_name'].toString()
                    : role,
              ),
              subtitle: Text(
                [
                  role,
                  if (account['staff_id'] != null) account['staff_id'],
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => account['staff_role'] == null
                      ? CustomerPreviewScreen(
                          repository: widget.repository,
                          id: account['id'].toString(),
                          byAccount: true,
                        )
                      : _StaffAccountPreview(
                          repository: widget.repository,
                          account: account,
                        ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _StaffAccountPreview extends StatefulWidget {
  const _StaffAccountPreview({required this.repository, required this.account});

  final PortalRepository repository;
  final Map<String, dynamic> account;

  @override
  State<_StaffAccountPreview> createState() => _StaffAccountPreviewState();
}

class _StaffAccountPreviewState extends State<_StaffAccountPreview> {
  final AppState _appState = AppState();
  late Future<void> _data = _load();
  String get _accountId => widget.account['id'].toString();
  bool get _isAdvisor => widget.account['staff_role'] == 'sales_advisor';

  Future<void> _load() async {
    final rows = await widget.repository.loadCustomers(
      advisorId: _isAdvisor ? _accountId : null,
    );
    if (mounted) _appState.replaceBackendCustomers(rows);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      await _load();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müşteri listesi yenilenemedi.')),
        );
    }
  }

  void _openCustomer(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerPreviewScreen(
          repository: widget.repository,
          id: customer.id,
          advisorId: _isAdvisor ? _accountId : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: Text('${widget.account['full_name']} adına')),
    body: FutureBuilder<void>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _data = _load()),
              child: const Text('Müşterileri yeniden yükle'),
            ),
          );
        }
        final customers = _appState.customers;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DelegatedConversationsScreen(
                        repository: widget.repository,
                        accountId: _accountId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Sohbetler'),
                ),
                if (!_isAdvisor) ...[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DelegatedPaymentsScreen(
                          repository: widget.repository,
                          accountId: _accountId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Dekontlar'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await showContractAccountReview(
                        context,
                        repository: widget.repository,
                        delegatedAccountId: _accountId,
                      );
                      await _refresh();
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Sözleşme eşleşmeleri'),
                  ),
                ],
              ],
            ),
            CustomerFolderManager(
              repository: widget.repository,
              customers: customers,
              onOpenCustomer: _openCustomer,
              delegatedAccountId: _accountId,
            ),
            if (customers.isEmpty)
              const ListTile(
                title: Text('Bu hesapta müşteri kaydı bulunamadı.'),
              ),
            for (final customer in customers)
              ListTile(
                title: Text(customer.name),
                subtitle: Text(
                  [
                    if (customer.projectName?.isNotEmpty == true)
                      customer.projectName,
                    if (customer.contractNo.isNotEmpty) customer.contractNo,
                  ].join(' · '),
                ),
                trailing: customer.isPendingContractRecord
                    ? _pendingDocument(customer)
                    : CustomerFolderAssignment(
                        key: ValueKey(customer.id),
                        repository: widget.repository,
                        customer: customer,
                        onChanged: _refresh,
                        delegatedAccountId: _accountId,
                      ),
                onTap: customer.isPendingContractRecord
                    ? null
                    : () => _openCustomer(customer),
              ),
          ],
        );
      },
    ),
  );

  Widget? _pendingDocument(Customer customer) =>
      customer.contractDocumentPath == null
      ? null
      : ContractDocumentButton(
          repository: widget.repository,
          customerId: customer.id,
          pending: true,
          label: 'Dosyayı aç',
        );
}
