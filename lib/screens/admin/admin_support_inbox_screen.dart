import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/portal_repository.dart';
import '../../widgets/website_blurred_background.dart';

class AdminSupportInboxScreen extends StatefulWidget {
  const AdminSupportInboxScreen({
    super.key,
    required this.repository,
    this.closedOnly = false,
  });

  final PortalRepository repository;
  final bool closedOnly;

  @override
  State<AdminSupportInboxScreen> createState() =>
      _AdminSupportInboxScreenState();
}

class _AdminSupportInboxScreenState extends State<AdminSupportInboxScreen> {
  List<Map<String, dynamic>> _tickets = const [];
  bool _loading = true;
  Object? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _ticketSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _ticketSubscription = widget.repository.watchMyTickets().listen((_) {
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.loadMyTickets();
      if (!mounted) return;
      setState(() {
        _tickets = rows
            .where((row) => (row['closed_at'] != null) == widget.closedOnly)
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.closedOnly ? 'Kapanan Sohbetler' : 'Müşteri Mesajları';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.closedOnly
                ? 'Müşterinin bitirdiği şirket sohbetleri tarih sırasıyla saklanır.'
                : 'Müşterilerden gelen ve açık kalan konuşmalar.',
            style: const TextStyle(color: Color(0xFFA9A39A), fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(
              'Yüklenemedi: $_error',
              style: const TextStyle(color: Color(0xFFE11D48)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (!_loading && _tickets.isEmpty)
            _emptyState(
              context,
              widget.closedOnly
                  ? 'Kapanmış sohbet yok.'
                  : 'Açık müşteri sohbeti yok.',
            ),
          ..._tickets.map((ticket) => _ticketTile(context, ticket)),
        ],
      ),
    );
  }

  Widget _ticketTile(BuildContext context, Map<String, dynamic> ticket) {
    final customer = ticket['customer'] as Map<String, dynamic>? ?? const {};
    final messages = ticket['ticket_messages'] as List? ?? const [];
    final lastMessage = messages.isEmpty
        ? null
        : messages.last as Map<String, dynamic>;
    final label = switch (ticket['channel']) {
      'advisor' => 'Satış danışmanı',
      'finance' => 'Muhasebe',
      _ => 'Şirket yetkilisi',
    };
    final isQuick = ticket['is_quick_conversation'] == true;
    final dateValue = ticket[widget.closedOnly ? 'closed_at' : 'updated_at']
        ?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: CupertinoButton(
          padding: const EdgeInsets.all(14),
          onPressed: () => _openConversation(ticket),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      (isQuick
                              ? const Color(0xFFFF9F0A)
                              : const Color(0xFFE11D48))
                          .withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isQuick
                      ? CupertinoIcons.bolt_horizontal_circle_fill
                      : CupertinoIcons.chat_bubble_2_fill,
                  color: isQuick ? Color(0xFFFF9F0A) : Color(0xFFE11D48),
                  size: 17,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['full_name']?.toString() ?? 'Müşteri',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isQuick ? 'Hızlı görüşme' : label}${customer['contract_number'] == null ? '' : ' • ${customer['contract_number']}'}',
                      style: const TextStyle(
                        color: Color(0xFFA9A39A),
                        fontSize: 11,
                      ),
                    ),
                    if (lastMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastMessage['body']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCDC8C0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dateValue != null)
                    Text(
                      dateValue.substring(0, 10),
                      style: const TextStyle(
                        color: Color(0xFF8D877F),
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: Color(0xFF9C958C),
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openConversation(Map<String, dynamic> ticket) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminConversation(
        repository: widget.repository,
        ticket: ticket,
        readOnly: widget.closedOnly,
      ),
    );
    if (mounted) unawaited(_load());
  }

  Widget _emptyState(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFA9A39A), fontSize: 13),
      ),
    ),
  );
}

class _AdminConversation extends StatefulWidget {
  const _AdminConversation({
    required this.repository,
    required this.ticket,
    required this.readOnly,
  });
  final PortalRepository repository;
  final Map<String, dynamic> ticket;
  final bool readOnly;

  @override
  State<_AdminConversation> createState() => _AdminConversationState();
}

class _AdminConversationState extends State<_AdminConversation> {
  final _controller = TextEditingController();
  PlatformFile? _selectedAttachment;
  Uint8List? _selectedAttachmentBytes;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> _messages = const [];
  bool _sending = false;

  String get _ticketId => widget.ticket['id'].toString();

  @override
  void initState() {
    super.initState();
    unawaited(_initMessages());
  }

  Future<void> _initMessages() async {
    try {
      final messages = await widget.repository.loadTicketMessages(_ticketId);
      if (mounted) setState(() => _messages = messages);
      _subscription = widget.repository.watchTicketMessages(_ticketId).listen((
        rows,
      ) {
        if (mounted) setState(() => _messages = rows);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mesajlar yüklenemedi: $error')));
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final file = _selectedAttachment;
    if ((text.isEmpty && file == null) ||
        (file != null && _selectedAttachmentBytes == null) ||
        _sending ||
        widget.readOnly) {
      return;
    }
    setState(() => _sending = true);
    String? uploadedPath;
    try {
      if (file != null) {
        uploadedPath = await widget.repository.uploadTicketAttachment(
          ticketId: _ticketId,
          fileName: file.name,
          bytes: _selectedAttachmentBytes!,
          contentType: _attachmentContentType(file.name),
        );
      }
      await widget.repository.sendTicketMessage(
        ticketId: _ticketId,
        body: text,
        attachmentObjectPath: uploadedPath,
      );
      _controller.clear();
      if (mounted) {
        setState(() {
          _selectedAttachment = null;
          _selectedAttachmentBytes = null;
        });
      }
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await widget.repository.removeUnlinkedTicketAttachment(uploadedPath);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mesaj gönderilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    if (_sending || widget.readOnly) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('Dosya okunamadı.');
      }
      if (bytes.lengthInBytes > 104857600) {
        throw const FormatException('Ek dosya 100 MB sınırını aşıyor.');
      }
      setState(() {
        _selectedAttachment = file;
        _selectedAttachmentBytes = bytes;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dosya seçilemedi: $error')));
      }
    }
  }

  String _attachmentContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer =
        widget.ticket['customer'] as Map<String, dynamic>? ?? const {};
    final channel = widget.ticket['channel'];
    final channelLabel = channel == 'finance'
        ? 'Muhasebe'
        : channel == 'advisor'
        ? 'Satış danışmanı'
        : 'Şirket yetkilisi';
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .78,
        decoration: const BoxDecoration(
          color: Color(0xFF171615),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['full_name']?.toString() ?? 'Müşteri',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          channelLabel,
                          style: const TextStyle(
                            color: Color(0xFFA9A39A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Color(0xFF9C958C),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF363330)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final own =
                      message['sender_id'] == widget.repository.currentUserId;
                  return Align(
                    alignment: own
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .75,
                      ),
                      decoration: BoxDecoration(
                        color: own
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF292725),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((message['body']?.toString() ?? '')
                              .trim()
                              .isNotEmpty)
                            Text(
                              message['body'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          if (message['attachment_object_path'] != null)
                            CupertinoButton(
                              padding: const EdgeInsets.only(top: 6),
                              minimumSize: Size.zero,
                              onPressed: () async {
                                try {
                                  final url = await widget.repository
                                      .getTicketAttachmentUrl(
                                        message['attachment_object_path']
                                            .toString(),
                                      );
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Dosya açılamadı: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.paperclip,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Eki aç',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedAttachment != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.paperclip,
                              color: Color(0xFFE11D48),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedAttachment!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFA9A39A),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: _sending
                                  ? null
                                  : () => setState(() {
                                      _selectedAttachment = null;
                                      _selectedAttachmentBytes = null;
                                    }),
                              child: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: Color(0xFFA9A39A),
                                size: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: _sending ? null : _pickAttachment,
                          child: const Icon(
                            CupertinoIcons.paperclip,
                            color: Color(0xFFA9A39A),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _controller,
                            placeholder: 'Yanıtınızı yazın...',
                            style: const TextStyle(color: Colors.white),
                            placeholderStyle: const TextStyle(
                              color: Color(0xFF8D877F),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF292725),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: _sending ? null : _send,
                          child: const Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            color: Color(0xFFE11D48),
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (widget.readOnly)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Bu sohbet müşteri tarafından kapatıldı. Arşiv kaydı saklanıyor.',
                  style: TextStyle(color: Color(0xFFA9A39A), fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
