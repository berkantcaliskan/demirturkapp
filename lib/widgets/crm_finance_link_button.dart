import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/portal_repository.dart';
import '../services/user_facing_error.dart';
import 'website_blurred_background.dart';

class CrmFinanceLinkButton extends StatelessWidget {
  const CrmFinanceLinkButton({
    super.key,
    required this.repository,
    required this.customer,
    required this.onChanged,
  });
  final PortalRepository repository;
  final Customer customer;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.link),
    label: const Text('CRM ödeme eşleştirmesi'),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _CrmPlanPicker(
        repository: repository,
        customer: customer,
        onChanged: onChanged,
      ),
    ),
  );
}

class _CrmPlanPicker extends StatefulWidget {
  const _CrmPlanPicker({
    required this.repository,
    required this.customer,
    required this.onChanged,
  });
  final PortalRepository repository;
  final Customer customer;
  final Future<void> Function() onChanged;
  @override
  State<_CrmPlanPicker> createState() => _CrmPlanPickerState();
}

class _CrmPlanPickerState extends State<_CrmPlanPicker> {
  late final _query = TextEditingController(text: widget.customer.name);
  final _selected = <String>{};
  final _rows = <Map<String, dynamic>>[];
  bool _busy = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _selected.addAll(
        await widget.repository.loadCrmLinkedPlanIds(widget.customer.id),
      );
    } catch (_) {
      /* Searching reports the actionable setup error. */
    }
    if (mounted) await _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool next = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.searchCrmFinancePlans(
        _query.text.trim(),
        after: next && _rows.isNotEmpty ? _rows.last['id'].toString() : '',
      );
      if (!mounted) return;
      setState(() {
        if (!next) _rows.clear();
        _rows.addAll(
          (result['records'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );
        _more = result['hasMore'] == true;
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'CRM planları alınamadı.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool unlink = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.linkCrmFinancePlans(
        widget.customer.id,
        unlink ? [] : _selected.toList()
          ..sort(),
      );
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'CRM eşleştirmesi yapılamadı.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Text(
            'CRM ödeme eşleştirmesi',
            style: TextStyle(
              color: AppGlass.textPrimary(context),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.customer.name} için kimliğini ve sözleşmesini kontrol ettiğiniz ödeme planlarını seçin.',
            style: TextStyle(
              color: AppGlass.textSecondary(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _query,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Müşteri adıyla ara',
              suffixIcon: IconButton(
                onPressed: _busy ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                for (final row in _rows)
                  CheckboxListTile(
                    value: _selected.contains(row['id']),
                    title: Text(
                      row['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Kimlik son 4: ${row['identitySuffix']}\n${row['issuedOn']} · ${row['totalAmount']} TL · ${row['noteCount']} senet',
                    ),
                    onChanged: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected == true && _selected.length < 10) {
                              _selected.add(row['id'].toString());
                            } else if (selected != true) {
                              _selected.remove(row['id']);
                            }
                          }),
                  ),
                if (_more)
                  TextButton(
                    onPressed: _busy ? null : () => _search(next: true),
                    child: const Text('Diğer planları yükle'),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _busy || _selected.isEmpty ? null : _save,
            child: Text('${_selected.length} ödeme planını bağla'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _save(unlink: true),
            child: const Text('Mevcut CRM eşleştirmesini kaldır'),
          ),
        ],
      ),
    ),
  );
}
