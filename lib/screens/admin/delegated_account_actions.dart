import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/portal_repository.dart';

class DelegatedConversationsScreen extends StatefulWidget {
  const DelegatedConversationsScreen({
    super.key,
    required this.repository,
    required this.accountId,
  });

  final PortalRepository repository;
  final String accountId;

  @override
  State<DelegatedConversationsScreen> createState() =>
      _DelegatedConversationsScreenState();
}

class _DelegatedConversationsScreenState
    extends State<DelegatedConversationsScreen> {
  late Future<List<Map<String, dynamic>>> _tickets = widget.repository
      .listDelegatedTickets(widget.accountId);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Hesabın sohbetleri')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _tickets,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _tickets = widget.repository.listDelegatedTickets(
                  widget.accountId,
                ),
              ),
              child: const Text('Sohbetleri yeniden yükle'),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!;
        if (tickets.isEmpty)
          return const Center(child: Text('Bu hesabın sohbeti yok.'));
        return ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return ListTile(
              title: Text(ticket['subject'].toString()),
              subtitle: Text(
                [
                  ticket['customer_name'],
                  if (ticket['closed_at'] != null) 'Kapalı',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _DelegatedConversationScreen(
                    repository: widget.repository,
                    accountId: widget.accountId,
                    ticket: ticket,
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

class _DelegatedConversationScreen extends StatefulWidget {
  const _DelegatedConversationScreen({
    required this.repository,
    required this.accountId,
    required this.ticket,
  });

  final PortalRepository repository;
  final String accountId;
  final Map<String, dynamic> ticket;

  @override
  State<_DelegatedConversationScreen> createState() =>
      _DelegatedConversationScreenState();
}

class _DelegatedConversationScreenState
    extends State<_DelegatedConversationScreen> {
  final _message = TextEditingController();
  late final String _ticketId = widget.ticket['id'].toString();
  late final _messages = widget.repository.watchTicketMessages(_ticketId);
  bool _sending = false;

  Future<void> _send() async {
    final text = _message.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.repository.performPortalAccountAction(
        widget.accountId,
        'send_message',
        {'ticket_id': _ticketId, 'body': text},
      );
      if (mounted) _message.clear();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mesaj gönderilemedi. Sohbet hâlâ açık mı kontrol edin.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: Text(widget.ticket['subject'].toString())),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text('Mesajlar yüklenemedi.'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.reversed.toList();
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final own = message['sender_id'] == widget.accountId;
                    return ListTile(
                      title: Text(message['body']?.toString() ?? ''),
                      subtitle: Text(own ? 'Seçilen hesap' : 'Gelen mesaj'),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.ticket['closed_at'] == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _message,
                enabled: !_sending,
                maxLength: 4000,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: 'Bu hesap adına mesaj yaz',
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: 'Mesajı gönder',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class DelegatedPaymentsScreen extends StatefulWidget {
  const DelegatedPaymentsScreen({
    super.key,
    required this.repository,
    required this.accountId,
  });

  final PortalRepository repository;
  final String accountId;

  @override
  State<DelegatedPaymentsScreen> createState() =>
      _DelegatedPaymentsScreenState();
}

class _DelegatedPaymentsScreenState extends State<DelegatedPaymentsScreen> {
  late Future<List<Map<String, dynamic>>> _payments = widget.repository
      .loadPendingPaymentReviews();
  bool _reviewing = false;

  Future<void> _openReceipt(String path) async {
    try {
      final url = await widget.repository.getPaymentReceiptUrl(path);
      if (!mounted) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication))
        throw StateError('No receipt viewer');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dekont açılamadı.')));
    }
  }

  Future<void> _review(String submissionId) async {
    if (_reviewing) return;
    String reason = '';
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu hesap adına dekontu incele'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Ret gerekçesi'),
          onChanged: (value) => reason = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'rejected'),
            child: const Text('Reddet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'approved'),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (decision == null || !mounted) return;
    setState(() => _reviewing = true);
    try {
      await widget.repository.performPortalAccountAction(
        widget.accountId,
        'review_payment',
        {'submission_id': submissionId, 'decision': decision, 'reason': reason},
      );
      if (mounted)
        setState(
          () => _payments = widget.repository.loadPendingPaymentReviews(),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Karar kaydedilemedi. Dekont daha önce incelenmiş olabilir.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Bekleyen dekontlar')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _payments,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _payments = widget.repository.loadPendingPaymentReviews(),
              ),
              child: const Text('Dekontları yeniden yükle'),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final payments = snapshot.data!;
        if (payments.isEmpty)
          return const Center(child: Text('İncelenmeyi bekleyen dekont yok.'));
        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            final customer = payment['customers'] as Map?;
            final note = payment['promissory_notes'] as Map?;
            final receiptPath = payment['receipt_object_path'] as String?;
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      customer?['full_name']?.toString() ?? 'Müşteri',
                    ),
                    subtitle: Text(note?['note_number']?.toString() ?? ''),
                  ),
                  Wrap(
                    children: [
                      if (receiptPath != null)
                        TextButton(
                          onPressed: () => _openReceipt(receiptPath),
                          child: const Text('Dekontu aç'),
                        ),
                      TextButton(
                        onPressed: _reviewing
                            ? null
                            : () => _review(payment['id'].toString()),
                        child: const Text('İncele'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
