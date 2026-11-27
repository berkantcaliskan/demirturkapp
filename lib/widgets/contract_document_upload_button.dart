import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/portal_repository.dart';
import '../services/upload_policy.dart';

class ContractDocumentUploadButton extends StatefulWidget {
  const ContractDocumentUploadButton({super.key, required this.repository,
    required this.contractId, required this.onSaved});
  final PortalRepository repository;
  final String contractId;
  final VoidCallback onSaved;
  @override
  State<ContractDocumentUploadButton> createState() => _ContractDocumentUploadButtonState();
}

class _ContractDocumentUploadButtonState extends State<ContractDocumentUploadButton> {
  bool _saving = false;
  Future<void> _upload() async {
    setState(() => _saving = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx']);
      if (file == null) return;
      final bytes = await UploadPolicy.readFile(file, UploadPolicy.contractBytes);
      await widget.repository.attachPendingContractDocument(
        contractId: widget.contractId, fileName: file.name, bytes: bytes);
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sözleşme yüklenemedi. PDF veya Word dosyasını ve bağlantınızı kontrol edin.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _saving ? null : _upload,
    icon: const Icon(Icons.upload_file),
    label: Text(_saving ? 'Yükleniyor…' : 'Sözleşme dosyası ekle'),
  );
}
