import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';

class CustomerSupportScreen extends StatelessWidget {
  final AppState appState;

  const CustomerSupportScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final tickets = appState.customerTickets;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Company Direct Contact Card (iOS Frosted Glass)
        GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0xFF64D2FF).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.building_2_fill,
                      color: Color(0xFF64D2FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demirtürk İnşaat • Karasu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Doğu Karadeniz Cd. No: 1, Aziziye, Karasu • 09:00 - 20:00',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppGlass.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildContactButton(
                      context,
                      icon: CupertinoIcons.chat_bubble_text_fill,
                      label: 'WhatsApp Hattı',
                      sublabel: '+90 531 373 00 54',
                      color: const Color(0xFF30D158),
                      message:
                          'Demirtürk İnşaat WhatsApp Hattı (+90 531 373 00 54) açılıyor...',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildContactButton(
                      context,
                      icon: CupertinoIcons.phone_fill,
                      label: 'Merkez Ofis',
                      sublabel: '0264 718 00 54',
                      color: const Color(0xFF64D2FF),
                      message:
                          'Demirtürk İnşaat Merkez Ofis (0264 718 00 54) aranıyor...',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Support Tickets Header + New Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mesajlarım & Destek Talepleri',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
            IosGlassButton(
              onTap: () => _showNewTicketSheet(context),
              color: const Color(0xFFFF9F0A),
              icon: CupertinoIcons.plus_bubble_fill,
              label: 'Yeni Mesaj',
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              borderRadius: 18,
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (tickets.isEmpty)
          GlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2,
                  size: 44,
                  color: AppGlass.textMuted(context),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Henüz aktif bir destek talebiniz bulunmuyor.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Senet vadesi, ödeme bildirimi veya yapılandırma talepleriniz için "Yeni Mesaj" butonuna tıklayabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppGlass.textSecondary(context),
                  ),
                ),
              ],
            ),
          )
        else
          ...tickets.map((ticket) {
            final lastMessage =
                ticket.messages.isNotEmpty ? ticket.messages.last : null;
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 20,
              child: CupertinoButton(
                padding: const EdgeInsets.all(16),
                pressedOpacity: 0.7,
                onPressed: () => showTicketChatModal(
                  context,
                  appState: appState,
                  ticketId: ticket.id,
                  isAdminMode: false,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0A84FF).withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF64D2FF)
                                  .withValues(alpha: 0.45),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            ticket.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64D2FF),
                            ),
                          ),
                        ),
                        if (ticket.relatedSenetNo != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              ticket.relatedSenetNo!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: ticket.isResolved
                                ? const Color(0xFF30D158).withValues(alpha: 0.22)
                                : const Color(0xFFFF9F0A)
                                    .withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ticket.isResolved
                                  ? const Color(0xFF30D158)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFFFD60A)
                                      .withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            ticket.isResolved ? 'Çözüldü' : 'Açık Talep',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ticket.isResolved
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFFFFD60A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    if (lastMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${lastMessage.isFromAdmin ? "Şirket Yetkilisi" : "Siz"}: ${lastMessage.text}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppGlass.textSecondary(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Son mesaj: ${formatShortDate(ticket.updatedAt)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppGlass.textMuted(context),
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Konuşmayı Aç',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64D2FF),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 14,
                              color: Color(0xFF64D2FF),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildContactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required String message,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 0.7),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppGlass.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewTicketSheet(BuildContext context) {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String selectedCategory = 'Vade & Ödeme Planı';
    String? selectedSenetNo = appState.customerNotes.isNotEmpty
        ? appState.customerNotes.first.senetNo
        : null;

    final categories = [
      'Vade & Ödeme Planı',
      'Dekont & Tahsilat',
      'Senet Yapılandırma / Erteleme',
      'Hesap Ekstresi & Borç Mutabakatı',
      'Diğer Konular',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: IosGlassSheet(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.plus_bubble_fill,
                            color: Color(0xFF64D2FF),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Şirkete Yeni Mesaj / Destek Talebi',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () => Navigator.pop(ctx),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Konu Kategorisi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((c) {
                          final active = c == selectedCategory;
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () =>
                                setModalState(() => selectedCategory = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF0A84FF)
                                        .withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Konu Başlığı',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: subjectCtrl,
                        placeholder: 'Örn: Kasım Ayı Senet Ödemesi Hakkında',
                        placeholderStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13.5,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mesajınız',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: msgCtrl,
                        maxLines: 3,
                        placeholder:
                            'Şirket yetkilisine iletmek istediğiniz mesajı yazınız...',
                        placeholderStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13.5,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: IosGlassButton(
                          icon: CupertinoIcons.paperplane_fill,
                          label: 'Mesajı Şirkete Gönder',
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          onTap: () {
                            if (subjectCtrl.text.trim().isEmpty ||
                                msgCtrl.text.trim().isEmpty) {
                              return;
                            }
                            final created = appState.createSupportTicket(
                              subject: subjectCtrl.text.trim(),
                              category: selectedCategory,
                              relatedSenetNo: selectedSenetNo,
                              initialMessage: msgCtrl.text.trim(),
                            );
                            Navigator.pop(ctx);
                            showTicketChatModal(
                              context,
                              appState: appState,
                              ticketId: created.id,
                              isAdminMode: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

void showTicketChatModal(
  BuildContext context, {
  required AppState appState,
  required String ticketId,
  required bool isAdminMode,
}) {
  final msgController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final ticket =
              appState.allTickets.firstWhere((t) => t.id == ticketId);
          final customer = appState.getCustomerById(ticket.customerId);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: IosGlassSheet(
              maxHeightFactor: 0.84,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ticket.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${customer.name} • ${ticket.category}${ticket.relatedSenetNo != null ? " • ${ticket.relatedSenetNo}" : ""}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAdminMode)
                              CupertinoButton(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                onPressed: () =>
                                    appState.toggleTicketResolved(ticket.id),
                                child: Text(
                                  ticket.isResolved
                                      ? 'Yeniden Aç'
                                      : 'Çözüldü İşaretle',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64D2FF),
                                  ),
                                ),
                              ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () => Navigator.pop(ctx),
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: ticket.messages.length,
                      itemBuilder: (context, index) {
                        final msg = ticket.messages[index];
                        final isMine =
                            isAdminMode ? msg.isFromAdmin : !msg.isFromAdmin;

                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMine
                                    ? [
                                        const Color(0xFF0A84FF)
                                            .withValues(alpha: 0.88),
                                        const Color(0xFF0066CC)
                                            .withValues(alpha: 0.78),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.18),
                                        Colors.white.withValues(alpha: 0.10),
                                      ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 18),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: isMine ? 0.35 : 0.22,
                                ),
                                width: 0.7,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : const Color(0xFF64D2FF),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.text,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                                if (msg.attachmentName != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.paperclip,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            msg.attachmentName!,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: msgController,
                            placeholder: isAdminMode
                                ? 'Şirket yetkilisi olarak yanıt yazın...'
                                : 'iMessage tarzı mesajınızı yazın...',
                            placeholderStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13.5,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.7,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () {
                            if (msgController.text.trim().isEmpty) return;
                            appState.sendTicketMessage(
                              ticketId: ticket.id,
                              text: msgController.text.trim(),
                              isFromAdmin: isAdminMode,
                            );
                            msgController.clear();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0A84FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_up,
                              color: Colors.white,
                              size: 20,
                            ),
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
      );
    },
  );
}
