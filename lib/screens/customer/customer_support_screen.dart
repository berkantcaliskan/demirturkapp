import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import 'website_iframe_stub.dart'
    if (dart.library.html) 'website_iframe_web.dart';

class CustomerSupportScreen extends StatefulWidget {
  final AppState appState;

  const CustomerSupportScreen({
    super.key,
    required this.appState,
  });

  static const String companyPhoneTelUrl = 'tel:+905436673454';

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  String? _inlineTicketId;

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final advisor = widget.appState.currentSalesAdvisor;

    // Satış danışmanı veya muhasebe için sayfa içi (inline) pencere açıksa onu göster
    if (_inlineTicketId != null) {
      final ticket = widget.appState.allTickets
          .where((t) => t.id == _inlineTicketId)
          .firstOrNull;
      if (ticket != null) {
        return _InlineConversationPage(
          key: ValueKey<String>('inline_${ticket.id}'),
          appState: widget.appState,
          ticket: ticket,
          advisor: advisor,
          isDark: isDark,
          onBack: () => setState(() => _inlineTicketId = null),
        );
      }
    }

    final financeTicket = widget.appState.customerTickets
        .where((t) => t.channel == 'finance')
        .firstOrNull;

    // Satış danışmanı ve muhasebe dışındaki aktif (bitirilmemiş ve mesaj içeren) konuşmalar alttaki boşluğa düşer
    final activeOtherTickets = widget.appState.customerTickets
        .where(
          (t) =>
              t.channel != 'advisor' &&
              t.channel != 'finance' &&
              !t.isEndedByCustomer &&
              t.messages.isNotEmpty,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // 1. Üst Kısım (Kartsız): Solda küçük büyük-harf "SATIŞ DANIŞMANIM", altında büyük punto danışman adı (soyadsız), sağda yuvarlak profil fotoğrafı
        _AssignedSalesAdvisorHeader(
          advisor: advisor,
          onTap: () {
            final ticket = widget.appState.getOrCreateChannelTicket('advisor');
            setState(() {
              _inlineTicketId = ticket.id;
            });
          },
        ),
        const SizedBox(height: 18),

        // 2. Muhasebe İletişim Kartı (Küçültülmüş; mesaj gelirse aşağıya doğru genişler)
        _FinanceSpecialistCard(
          lastMessage: (financeTicket != null &&
                  financeTicket.messages.isNotEmpty)
              ? financeTicket.messages.last
              : null,
          onTap: () {
            final ticket = widget.appState.getOrCreateChannelTicket('finance');
            setState(() {
              _inlineTicketId = ticket.id;
            });
          },
        ),
        const SizedBox(height: 12),

        // 3. Alt Butonlar: "Şimdi bir yetkiliyle mesajlaş" + "Ara" (Açıklamasız, eşit düşey yükseklikte)
        _GeneralCompanyActionRow(
          isDark: isDark,
          onMessageRepresentativeTap: () {
            final ticket = widget.appState.getOrCreateChannelTicket('general');
            _showGeneralChatSheet(
              context,
              appState: widget.appState,
              ticketId: ticket.id,
            );
          },
          onCallTap: () {
            launchPhoneDialer(CustomerSupportScreen.companyPhoneTelUrl);
          },
        ),

        // 4. Alttaki Boşluk: Satış danışmanı dışındaki yeni/aktif mesajlar buraya düşer
        if (activeOtherTickets.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...activeOtherTickets.map((ticket) {
            final lastMsg = ticket.messages.last;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                borderRadius: 20,
                padding: EdgeInsets.zero,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  pressedOpacity: 0.75,
                  onPressed: () {
                    _showGeneralChatSheet(
                      context,
                      appState: widget.appState,
                      ticketId: ticket.id,
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF30D158),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.subject,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: AppGlass.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${lastMsg.senderName}: ${lastMsg.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppGlass.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: AppGlass.textMuted(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _AssignedSalesAdvisorHeader extends StatelessWidget {
  final SalesAdvisor advisor;
  final VoidCallback onTap;

  const _AssignedSalesAdvisorHeader({
    required this.advisor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SATIŞ DANIŞMANIM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppGlass.textMuted(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  advisor.firstName,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                    letterSpacing: -0.5,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: SizedBox(
              width: 54,
              height: 54,
              child: Image.network(
                advisor.photoUrl,
                key: ValueKey<String>(
                  '${advisor.id}_${advisor.photoUrl}_${advisor.photoUpdatedAt.millisecondsSinceEpoch}',
                ),
                fit: BoxFit.cover,
                alignment: const Alignment(0.0, -0.25),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppGlass.subtleSurface(context),
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: 26,
                      color: AppGlass.textSecondary(context),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSpecialistCard extends StatelessWidget {
  final ChatMessage? lastMessage;
  final VoidCallback onTap;

  const _FinanceSpecialistCard({
    required this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        minimumSize: Size.zero,
        pressedOpacity: 0.78,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppGlass.subtleSurface(context),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    CupertinoIcons.briefcase_fill,
                    size: 16,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Finans Uzmanımız ile görüşün',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: AppGlass.textSecondary(context),
                ),
              ],
            ),
            if (lastMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppGlass.subtleSurface(context),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF30D158),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${lastMessage!.senderName}: ${lastMessage!.text}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppGlass.textSecondary(context),
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
  }
}

class _GeneralCompanyActionRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onMessageRepresentativeTap;
  final VoidCallback onCallTap;

  const _GeneralCompanyActionRow({
    required this.isDark,
    required this.onMessageRepresentativeTap,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 52.0;

    return Row(
      children: [
        // Sol: Şimdi bir yetkiliyle mesajlaş (Açıklamasız, Ara ile eşit yükseklikte)
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: GlassCard(
              borderRadius: 18,
              padding: EdgeInsets.zero,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: Size.zero,
                pressedOpacity: 0.78,
                onPressed: onMessageRepresentativeTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble_2_fill,
                      size: 17,
                      color: AppGlass.textPrimary(context),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        'Şimdi bir yetkiliyle mesajlaş',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                          color: AppGlass.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Sağ: Ara (Eşit düşey yükseklikte)
        SizedBox(
          height: buttonHeight,
          child: GlassCard(
            borderRadius: 18,
            padding: EdgeInsets.zero,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: Size.zero,
              pressedOpacity: 0.78,
              onPressed: onCallTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.phone_fill,
                    size: 16,
                    color: Color(0xFF30D158),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Ara',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satış Danışmanı ve Muhasebe için İletişim sayfası içinde açılan normal pencere (sayfa)
class _InlineConversationPage extends StatefulWidget {
  final AppState appState;
  final SupportTicket ticket;
  final SalesAdvisor advisor;
  final bool isDark;
  final VoidCallback onBack;
  final bool isAdminMode;

  const _InlineConversationPage({
    super.key,
    required this.appState,
    required this.ticket,
    required this.advisor,
    required this.isDark,
    required this.onBack,
    this.isAdminMode = false,
  });

  @override
  State<_InlineConversationPage> createState() =>
      _InlineConversationPageState();
}

class _InlineConversationPageState extends State<_InlineConversationPage> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage(SupportTicket liveTicket) {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    widget.appState.sendTicketMessage(
      ticketId: liveTicket.id,
      text: text,
      isFromAdmin: widget.isAdminMode,
    );
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final liveTicket = widget.appState.allTickets.firstWhere(
      (t) => t.id == widget.ticket.id,
      orElse: () => widget.ticket,
    );
    final isDark = AppGlass.isDark(context);

    final String title = liveTicket.channel == 'advisor'
        ? widget.advisor.firstName
        : (liveTicket.channel == 'finance'
            ? 'Finans Uzmanımız'
            : liveTicket.subject);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 94),
      child: GlassCard(
        borderRadius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Üst Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
              child: Row(
                children: [
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    onPressed: widget.onBack,
                    child: Icon(
                      CupertinoIcons.chevron_back,
                      size: 20,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                  if (liveTicket.channel == 'advisor') ...[
                    const SizedBox(width: 4),
                    ClipOval(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Image.network(
                          widget.advisor.photoUrl,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.0, -0.25),
                          errorBuilder: (_, _, _) => Container(
                            color: AppGlass.subtleSurface(context),
                            child: Icon(
                              CupertinoIcons.person_fill,
                              size: 17,
                              color: AppGlass.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppGlass.dividerColor(context),
            ),

            // Mesaj Listesi
            Expanded(
              child: liveTicket.messages.isEmpty
                  ? const SizedBox.expand()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: liveTicket.messages.length,
                      itemBuilder: (context, index) {
                        final msg = liveTicket.messages[index];
                        final isMine = widget.isAdminMode
                            ? msg.isFromAdmin
                            : !msg.isFromAdmin;

                        final bubbleBg = isMine
                            ? (isDark
                                ? const Color(0xFFF5F3F0)
                                : const Color(0xFF1E293B))
                            : AppGlass.subtleSurface(context);

                        final bubbleText = isMine
                            ? (isDark
                                ? const Color(0xFF141312)
                                : Colors.white)
                            : AppGlass.textPrimary(context);

                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.74,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleBg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 18),
                              ),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: bubbleText,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Mesaj Yazma Barı
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppGlass.dividerColor(context),
                    width: 0.6,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _msgController,
                      placeholder: 'Mesajınızı yazın...',
                      placeholderStyle: TextStyle(
                        color: AppGlass.textMuted(context),
                        fontSize: 13.5,
                      ),
                      style: TextStyle(
                        color: AppGlass.textPrimary(context),
                        fontSize: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppGlass.subtleSurface(context),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      onSubmitted: (_) => _sendMessage(liveTicket),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _sendMessage(liveTicket),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFF5F3F0)
                            : const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        color:
                            isDark ? const Color(0xFF141312) : Colors.white,
                        size: 18,
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
  }
}

/// Yalnızca Genel Mesajlaşma ("Şimdi bir yetkiliyle mesajlaş") için açılır menü (bottom sheet)
void _showGeneralChatSheet(
  BuildContext context, {
  required AppState appState,
  required String ticketId,
}) {
  final msgController = TextEditingController();

  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      return AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final isDark = AppGlass.isDark(context);
          final ticket = appState.allTickets
              .where((t) => t.id == ticketId)
              .firstOrNull;

          if (ticket == null) {
            return const SizedBox.shrink();
          }

          void sendMsg() {
            if (msgController.text.trim().isEmpty) return;
            appState.sendTicketMessage(
              ticketId: ticket.id,
              text: msgController.text.trim(),
              isFromAdmin: false,
            );
            msgController.clear();
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: IosGlassSheet(
              maxHeightFactor: 0.80,
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
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFF0F172A)
                                    .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Yetkili ile Mesajlaş',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: -0.3,
                                  color: AppGlass.textPrimary(context),
                                ),
                              ),
                            ),
                            // Sohbeti Bitir (Müşteride kaybolur, şirkette depolanır)
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              minimumSize: Size.zero,
                              onPressed: () {
                                appState.endCustomerChat(ticket.id);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Sohbeti Bitir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () => Navigator.pop(ctx),
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: AppGlass.textMuted(context),
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
                    color: AppGlass.dividerColor(context),
                  ),
                  Expanded(
                    child: ticket.messages.isEmpty
                        ? const SizedBox.expand()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: ticket.messages.length,
                            itemBuilder: (context, index) {
                              final msg = ticket.messages[index];
                              final isMine = !msg.isFromAdmin;

                              final bubbleBg = isMine
                                  ? (isDark
                                      ? const Color(0xFFF5F3F0)
                                      : const Color(0xFF1E293B))
                                  : AppGlass.subtleSurface(context);

                              final bubbleText = isMine
                                  ? (isDark
                                      ? const Color(0xFF141312)
                                      : Colors.white)
                                  : AppGlass.textPrimary(context);

                              return Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.76,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bubbleBg,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft:
                                          Radius.circular(isMine ? 18 : 4),
                                      bottomRight:
                                          Radius.circular(isMine ? 4 : 18),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: bubbleText,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                    decoration: BoxDecoration(
                      color: AppGlass.subtleSurface(context),
                      border: Border(
                        top: BorderSide(
                          color: AppGlass.dividerColor(context),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: msgController,
                            placeholder: 'Mesajınızı yazın...',
                            placeholderStyle: TextStyle(
                              color: AppGlass.textMuted(context),
                              fontSize: 13.5,
                            ),
                            style: TextStyle(
                              color: AppGlass.textPrimary(context),
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF211F1D)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppGlass.dividerColor(context),
                                width: 0.7,
                              ),
                            ),
                            onSubmitted: (_) => sendMsg(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: sendMsg,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFF5F3F0)
                                  : const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.arrow_up,
                              color: isDark
                                  ? const Color(0xFF141312)
                                  : Colors.white,
                              size: 19,
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

/// Yönetici panelinde hiçbir koşulda açılır menü (bottom sheet) olmaz; tam sayfa pencere olarak açılır
void showTicketChatModal(
  BuildContext context, {
  required AppState appState,
  required String ticketId,
  required bool isAdminMode,
}) {
  if (!isAdminMode) {
    _showGeneralChatSheet(
      context,
      appState: appState,
      ticketId: ticketId,
    );
    return;
  }

  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (pageCtx) {
        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final isDark = AppGlass.isDark(context);
            final ticket = appState.allTickets
                .where((t) => t.id == ticketId)
                .firstOrNull;
            if (ticket == null) {
              return const SizedBox.shrink();
            }
            final customer = appState.getCustomerById(ticket.customerId);
            final advisor = appState.salesAdvisors.firstWhere(
              (a) => a.id == customer.assignedAdvisorId,
              orElse: () => appState.salesAdvisors.first,
            );
            return Scaffold(
              backgroundColor:
                  isDark ? const Color(0xFF141312) : const Color(0xFFEEF2F6),
              body: SafeArea(
                child: _InlineConversationPage(
                  appState: appState,
                  ticket: ticket,
                  advisor: advisor,
                  isDark: isDark,
                  isAdminMode: true,
                  onBack: () => Navigator.of(pageCtx).pop(),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
