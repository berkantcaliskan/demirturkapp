import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/portal_repository.dart';

class ContractDocumentButton extends StatefulWidget {
  const ContractDocumentButton({
    super.key,
    required this.repository,
    required this.customerId,
    this.pending = false,
    this.label = 'Sözleşmeyi gör',
  });

  final PortalRepository repository;
  final String customerId;
  final bool pending;
  final String label;

  @override
  State<ContractDocumentButton> createState() => _ContractDocumentButtonState();
}

class _ContractDocumentButtonState extends State<ContractDocumentButton> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final url = await widget.repository.getContractDocumentUrl(
        widget.customerId,
        pending: widget.pending,
      );
      if (!mounted) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('No app can open the contract URL');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sözleşme dosyası açılamadı. Tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _opening ? null : _open,
    icon: const Icon(Icons.description_outlined),
    label: Text(_opening ? 'Açılıyor…' : widget.label),
  );
}
