import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../services/portal_repository.dart';
import '../../widgets/website_blurred_background.dart';
import 'website_iframe_stub.dart'
    if (dart.library.html) 'website_iframe_web.dart';

class CustomerSupportScreen extends StatefulWidget {
  final AppState appState;
  final PortalRepository? repository;

  const CustomerSupportScreen({
    super.key,
    required this.appState,
    this.repository,
  });

  static const String companyPhoneTelUrl = 'tel:+905313730054';

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  String? _inlineTicketId;

  @override
  Widget build(BuildContext context) {
    if (widget.repository != null) {
      return _BackendSupportScreen(
        appState: widget.appState,
        repository: widget.repository!,
      );
    }
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
          lastMessage:
              (financeTicket != null && financeTicket.messages.isNotEmpty)
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
                    'Finans uzmanımız ile görüşün',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
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
                  if (liveTicket.channel == 'advisor')
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      pressedOpacity: 0.72,
                      onPressed: () {
                        final digits = widget.advisor.phone.replaceAll(
                          RegExp(r'[^0-9+]'),
                          '',
                        );
                        final telUrl = digits.isNotEmpty
                            ? 'tel:$digits'
                            : CustomerSupportScreen.companyPhoneTelUrl;
                        launchPhoneDialer(telUrl);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFF5F3F0)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.phone_fill,
                              size: 13.5,
                              color: isDark
                                  ? const Color(0xFF141312)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Ara',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? const Color(0xFF141312)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: AppGlass.dividerColor(context)),

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
                            ? (isDark ? const Color(0xFF141312) : Colors.white)
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
                        color: isDark ? const Color(0xFF141312) : Colors.white,
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
                  Divider(height: 1, color: AppGlass.dividerColor(context)),
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
                                      bottomLeft: Radius.circular(
                                        isMine ? 18 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMine ? 4 : 18,
                                      ),
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

class _BackendSupportScreen extends StatefulWidget {
  const _BackendSupportScreen({
    required this.appState,
    required this.repository,
  });

  final AppState appState;
  final PortalRepository repository;

  @override
  State<_BackendSupportScreen> createState() => _BackendSupportScreenState();
}

class _BackendSupportScreenState extends State<_BackendSupportScreen> {
  List<Map<String, dynamic>> _tickets = const [];
  List<Map<String, dynamic>> _messages = const [];
  String? _activeTicketId;
  String? _activeChannel;
  bool _loading = true;
  bool _sending = false;
  Object? _loadError;
  final _messageController = TextEditingController();
  PlatformFile? _selectedAttachment;
  Uint8List? _selectedAttachmentBytes;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTickets());
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      final tickets = await widget.repository.loadMyTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets
            .where(
              (ticket) =>
                  ticket['hidden_for_customer_at'] == null &&
                  ticket['deleted_at'] == null,
            )
            .toList();
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _openChannel(String channel) async {
    if (channel == 'advisor' &&
        widget.appState.currentCustomer.assignedAdvisorId.isEmpty) {
      _showError(
        'Satış danışmanınız henüz atanmadı. Şirket yetkilisiyle görüşebilirsiniz.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id = await widget.repository.getOrCreateCustomerTicket(channel);
      await _messageSubscription?.cancel();
      final messages = await widget.repository.loadTicketMessages(id);
      if (!mounted) return;
      setState(() {
        _activeTicketId = id;
        _activeChannel = channel;
        _messages = messages;
        _loading = false;
      });
      _messageSubscription = widget.repository
          .watchTicketMessages(id)
          .listen(
            (rows) {
              if (mounted) setState(() => _messages = rows);
            },
            onError: (Object error) {
              if (mounted) setState(() => _loadError = error);
            },
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _sendMessage() async {
    final id = _activeTicketId;
    final body = _messageController.text.trim();
    final file = _selectedAttachment;
    if (id == null ||
        (body.isEmpty && file == null) ||
        (file != null && _selectedAttachmentBytes == null) ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    String? uploadedPath;
    try {
      if (file != null) {
        uploadedPath = await widget.repository.uploadTicketAttachment(
          ticketId: id,
          fileName: file.name,
          bytes: _selectedAttachmentBytes!,
          contentType: _attachmentContentType(file.name),
        );
      }
      await widget.repository.sendTicketMessage(
        ticketId: id,
        body: body,
        attachmentObjectPath: uploadedPath,
      );
      _messageController.clear();
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
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickMessageAttachment() async {
    if (_sending) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showError(
          'Dosya okunamadı. Daha küçük bir dosya seçip tekrar deneyin.',
        );
        return;
      }
      if (bytes.lengthInBytes > 104857600) {
        _showError('Ek dosya 100 MB sınırını aşıyor.');
        return;
      }
      setState(() {
        _selectedAttachment = file;
        _selectedAttachmentBytes = bytes;
      });
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  String _attachmentContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _closeGeneralChat() async {
    final id = _activeTicketId;
    if (id == null) return;
    try {
      await widget.repository.closeGeneralTicket(id);
      await _leaveConversation();
      await _loadTickets();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteConversation(String channel) async {
    final id = _activeTicketId;
    if (id == null) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sohbet silinsin mi?'),
        content: const Text('Bu konuşma ve mesajları kalıcı olarak silinecek.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteMyTicket(id);
      await _leaveConversation();
      await _loadTickets();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _leaveConversation() async {
    await _messageSubscription?.cancel();
    if (mounted) {
      setState(() {
        _activeTicketId = null;
        _activeChannel = null;
        _messages = const [];
      });
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final active = _tickets
        .where((ticket) => ticket['id'] == _activeTicketId)
        .firstOrNull;
    if (_activeTicketId != null) {
      final channel =
          active?['channel']?.toString() ?? _activeChannel ?? 'general';
      final title = switch (channel) {
        'advisor' => widget.appState.currentSalesAdvisor.firstName,
        'finance' => 'Muhasebe',
        _ => 'Şirket yetkilisi',
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 94),
        child: GlassCard(
          borderRadius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minimumSize: Size.zero,
                      onPressed: _leaveConversation,
                      child: Icon(
                        CupertinoIcons.chevron_back,
                        color: AppGlass.textPrimary(context),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppGlass.textPrimary(context),
                        ),
                      ),
                    ),
                    if (channel == 'general')
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        onPressed: _closeGeneralChat,
                        child: const Text(
                          'Sohbeti bitir',
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        minimumSize: Size.zero,
                        onPressed: () => _deleteConversation(channel),
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: Color(0xFFE11D48),
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppGlass.dividerColor(context)),
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Mesajlaşmayı başlatın.',
                          style: TextStyle(color: AppGlass.textMuted(context)),
                        ),
                      )
                    : ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final own =
                              message['sender_id'] ==
                              widget.repository.currentUserId;
                          final bg = own
                              ? (isDark
                                    ? const Color(0xFFF5F3F0)
                                    : const Color(0xFF1E293B))
                              : AppGlass.subtleSurface(context);
                          final fg = own
                              ? (isDark
                                    ? const Color(0xFF141312)
                                    : Colors.white)
                              : AppGlass.textPrimary(context);
                          return Align(
                            alignment: own
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .74,
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(18),
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
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 13.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  if (message['attachment_object_path'] != null)
                                    CupertinoButton(
                                      padding: const EdgeInsets.only(top: 7),
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
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } catch (error) {
                                          if (context.mounted) {
                                            _showError(error);
                                          }
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.paperclip,
                                            size: 14,
                                            color: fg,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Eki aç',
                                            style: TextStyle(
                                              color: fg,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedAttachment != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                                style: TextStyle(
                                  color: AppGlass.textSecondary(context),
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
                          onPressed: _sending ? null : _pickMessageAttachment,
                          child: Icon(
                            CupertinoIcons.paperclip,
                            color: AppGlass.textSecondary(context),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _messageController,
                            placeholder: 'Mesajınızı yazın...',
                            style: TextStyle(
                              color: AppGlass.textPrimary(context),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: AppGlass.subtleSurface(context),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: _sending ? null : _sendMessage,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFF5F3F0)
                                  : const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.arrow_up,
                                    color: isDark
                                        ? const Color(0xFF141312)
                                        : Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final advisor = widget.appState.currentSalesAdvisor;
    Map<String, dynamic>? ticketFor(String channel) => _tickets
        .where(
          (ticket) =>
              ticket['channel'] == channel && ticket['closed_at'] == null,
        )
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Sohbetler yüklenemedi: $_loadError',
              style: const TextStyle(color: Color(0xFFE11D48)),
            ),
          ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : () => _openChannel('advisor'),
          child: _contactCard(
            advisor.firstName,
            'Satış danışmanınız',
            advisor.photoUrl,
          ),
        ),
        const SizedBox(height: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : () => _openChannel('finance'),
          child: _contactCard(
            'Muhasebe',
            ticketFor('finance') == null
                ? 'Muhasebe ekibine mesaj gönderin'
                : 'Konuşmaya devam edin',
            null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 13),
                color: AppGlass.subtleSurface(context),
                borderRadius: BorderRadius.circular(17),
                onPressed: _loading ? null : () => _openChannel('general'),
                child: Text(
                  'Şimdi bir yetkiliyle mesajlaş',
                  style: TextStyle(
                    color: AppGlass.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              color: AppGlass.subtleSurface(context),
              borderRadius: BorderRadius.circular(17),
              onPressed: () =>
                  launchPhoneDialer(CustomerSupportScreen.companyPhoneTelUrl),
              child: Icon(
                CupertinoIcons.phone,
                size: 17,
                color: AppGlass.textPrimary(context),
              ),
            ),
          ],
        ),
        if (ticketFor('general') case final Map<String, dynamic> ticket?)
          if ((ticket['closed_at'] == null) &&
              (ticket['ticket_messages'] as List? ?? const []).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: CupertinoButton(
                padding: const EdgeInsets.all(14),
                color: AppGlass.subtleSurface(context),
                borderRadius: BorderRadius.circular(17),
                onPressed: _loading ? null : () => _openChannel('general'),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.chat_bubble_2, size: 16),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Açık şirket sohbetine dön',
                        style: TextStyle(
                          color: AppGlass.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right, size: 14),
                  ],
                ),
              ),
            ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _contactCard(String title, String subtitle, String? photoUrl) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          if (photoUrl != null)
            ClipOval(
              child: Image.network(
                photoUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(CupertinoIcons.person_fill, size: 28),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppGlass.subtleSurface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.building_2_fill,
                size: 18,
                color: AppGlass.textSecondary(context),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppGlass.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppGlass.textSecondary(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: AppGlass.textMuted(context),
            size: 16,
          ),
        ],
      ),
    );
  }
}

/// Yönetici panelinde hiçbir koşulda açılır menü (bottom sheet) olmaz; tam sayfa pencere olarak açılır
void showTicketChatModal(
  BuildContext context, {
  required AppState appState,
  required String ticketId,
  required bool isAdminMode,
}) {
  if (!isAdminMode) {
    _showGeneralChatSheet(context, appState: appState, ticketId: ticketId);
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
            final advisor =
                appState.salesAdvisors
                    .where((a) => a.id == customer.assignedAdvisorId)
                    .firstOrNull ??
                appState.currentSalesAdvisor;
            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF141312)
                  : const Color(0xFFEEF2F6),
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
