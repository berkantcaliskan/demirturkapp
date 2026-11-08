import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import 'website_iframe_stub.dart'
    if (dart.library.html) 'website_iframe_web.dart';

class CustomerSupportScreen extends StatelessWidget {
  final AppState appState;

  const CustomerSupportScreen({
    super.key,
    required this.appState,
  });

  static const String companyPhoneDisplay = '+90 543 667 34 54';
  static const String companyPhoneTelUrl = 'tel:+905436673454';

  @override
  Widget build(BuildContext context) {
    final isDark = AppGlass.isDark(context);
    final advisor = appState.currentSalesAdvisor;
    final financeTicket = appState.customerTickets
        .where((t) => t.channel == 'finance')
        .firstOrNull;
    final advisorTicket = appState.customerTickets
        .where((t) => t.channel == 'advisor')
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // 1. Müşteriye Özel Atanmış Satış Danışmanı Kartı
        // ("Satış Danışmanım" ince fontla üstte, danışman adı büyük kalın fontla altta, sağda otomatik güncellenen danışman fotoğrafı)
        _AssignedSalesAdvisorCard(
          advisor: advisor,
          lastMessage: advisorTicket?.messages.lastOrNull,
          isDark: isDark,
          onMessageTap: () {
            final ticket = appState.getOrCreateChannelTicket('advisor');
            showTicketChatModal(
              context,
              appState: appState,
              ticketId: ticket.id,
              isAdminMode: false,
            );
          },
        ),
        const SizedBox(height: 16),

        // 2. Muhasebe İletişim Kısmı ("Finans Uzmanımız ile görüşün")
        _FinanceSpecialistCard(
          isDark: isDark,
          lastMessage: financeTicket?.messages.lastOrNull,
          onTap: () {
            final ticket = appState.getOrCreateChannelTicket('finance');
            showTicketChatModal(
              context,
              appState: appState,
              ticketId: ticket.id,
              isAdminMode: false,
            );
          },
        ),
        const SizedBox(height: 16),

        // 3. Alt Kısım: "Şimdi bir yetkiliyle mesajlaş" (Genel şirket paneline düşer) + Yanında "Ara" (+90 543 667 34 54)
        _GeneralCompanyActionRow(
          isDark: isDark,
          phoneDisplay: companyPhoneDisplay,
          onMessageRepresentativeTap: () {
            final ticket = appState.getOrCreateChannelTicket('general');
            showTicketChatModal(
              context,
              appState: appState,
              ticketId: ticket.id,
              isAdminMode: false,
            );
          },
          onCallTap: () {
            launchPhoneDialer(companyPhoneTelUrl);
          },
        ),
      ],
    );
  }
}

class _AssignedSalesAdvisorCard extends StatelessWidget {
  final SalesAdvisor advisor;
  final ChatMessage? lastMessage;
  final bool isDark;
  final VoidCallback onMessageTap;

  const _AssignedSalesAdvisorCard({
    required this.advisor,
    required this.lastMessage,
    required this.isDark,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFF5F3F0) : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? const Color(0xFF9C958C) : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        constraints: const BoxConstraints(minHeight: 196),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF211F1D) : Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            // Sağda danışmanın fotoğrafı (danışman fotoğrafını güncelledikçe otomatik güncellenir)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 195,
              child: ClipRect(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x00FFFFFF),
                        Color(0x0AFFFFFF),
                        Color(0x29FFFFFF),
                        Color(0x66FFFFFF),
                        Color(0xB3FFFFFF),
                        Color(0xEBFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                      ],
                      stops: [
                        0.00,
                        0.04,
                        0.09,
                        0.16,
                        0.25,
                        0.35,
                        0.44,
                        0.52,
                        1.00,
                      ],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.network(
                  advisor.photoUrl,
                  key: ValueKey<String>(
                    '${advisor.id}_${advisor.photoUrl}_${advisor.photoUpdatedAt.millisecondsSinceEpoch}',
                  ),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.0, -0.25),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDark
                          ? const Color(0xFF2B2825)
                          : const Color(0xFFE2E8F0),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 28),
                      child: Icon(
                        CupertinoIcons.person_crop_circle_fill,
                        size: 74,
                        color: subTextColor.withValues(alpha: 0.45),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

            // İnce kart kenarlığı
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFFF8F0).withValues(alpha: 0.08)
                          : const Color(0xFF0F172A).withValues(alpha: 0.05),
                      width: 0.7,
                    ),
                  ),
                ),
              ),
            ),

            // Sol Ön Yüz İçerik: Üstte ince fontla "Satış Danışmanım", altında büyük kalın fontla Danışman Adı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 130, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Satış Danışmanım',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          letterSpacing: -0.1,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        advisor.name,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.5,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 46),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    pressedOpacity: 0.8,
                    onPressed: onMessageTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFF5F3F0)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chat_bubble_text_fill,
                            size: 13.5,
                            color: isDark
                                ? const Color(0xFF141312)
                                : Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Danışmanla Görüş',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF141312)
                                  : Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
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

class _FinanceSpecialistCard extends StatelessWidget {
  final bool isDark;
  final ChatMessage? lastMessage;
  final VoidCallback onTap;

  const _FinanceSpecialistCard({
    required this.isDark,
    required this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: CupertinoButton(
        padding: const EdgeInsets.all(18),
        pressedOpacity: 0.78,
        onPressed: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppGlass.subtleSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppGlass.dividerColor(context),
                      width: 0.7,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.briefcase_fill,
                    size: 20,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finans Uzmanımız ile görüşün',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.35,
                          color: AppGlass.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Muhasebe & Finans Birimi • Doğrudan İletişim',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppGlass.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: AppGlass.textSecondary(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppGlass.subtleSurface(context),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF30D158),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      lastMessage != null
                          ? '${lastMessage!.isFromAdmin ? "Muhasebe" : "Siz"}: ${lastMessage!.text}'
                          : 'Senet vadesi, dekont onayı ve ödeme planı için muhasebe üyesine doğrudan ulaşın.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppGlass.textSecondary(context),
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

class _GeneralCompanyActionRow extends StatelessWidget {
  final bool isDark;
  final String phoneDisplay;
  final VoidCallback onMessageRepresentativeTap;
  final VoidCallback onCallTap;

  const _GeneralCompanyActionRow({
    required this.isDark,
    required this.phoneDisplay,
    required this.onMessageRepresentativeTap,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sol: Şimdi bir yetkiliyle mesajlaş (Genel şirket paneline düşer)
        Expanded(
          child: GlassCard(
            borderRadius: 22,
            padding: EdgeInsets.zero,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              pressedOpacity: 0.78,
              onPressed: onMessageRepresentativeTap,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFF5F3F0)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.bubble_left_bubble_right_fill,
                      size: 17,
                      color: isDark ? const Color(0xFF141312) : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şimdi bir yetkiliyle mesajlaş',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppGlass.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Genel şirket paneline düşer, müsait yetkili yanıtlar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppGlass.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Sağ: Ara (+90 543 667 34 54 - doğrudan telefona yönlendirir)
        GlassCard(
          borderRadius: 22,
          padding: EdgeInsets.zero,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            pressedOpacity: 0.78,
            onPressed: onCallTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.phone_fill,
                    size: 18,
                    color: Color(0xFF30D158),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ara',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  bool replyAsStaffInDemo = isAdminMode;

  showGlassBottomSheet(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AnimatedBuilder(
            animation: appState,
            builder: (context, _) {
              final isDark = AppGlass.isDark(context);
              final ticket = appState.allTickets.firstWhere(
                (t) => t.id == ticketId,
                orElse: () => appState.allTickets.first,
              );
              final customer = appState.getCustomerById(ticket.customerId);
              final advisor = appState.salesAdvisors.firstWhere(
                (a) => a.id == customer.assignedAdvisorId,
                orElse: () => appState.salesAdvisors.first,
              );

              final String headerTitle;
              final String headerSubtitle;
              final String staffRoleLabel;
              if (ticket.channel == 'advisor') {
                headerTitle = advisor.name;
                headerSubtitle = 'Satış Danışmanım • ${customer.projectTitle}';
                staffRoleLabel = 'Danışman Olarak Yanıtla';
              } else if (ticket.channel == 'finance') {
                headerTitle = 'Finans Uzmanımız';
                headerSubtitle =
                    'Muhasebe & Finans Birimi • İki Yönlü Doğrudan Görüşme';
                staffRoleLabel = 'Muhasebe Olarak Yanıtla';
              } else {
                headerTitle = 'Canlı Yetkili Destek Hattı';
                headerSubtitle =
                    'Genel Şirket Paneli • Müsait yetkili anında yanıtlar';
                staffRoleLabel = 'Yetkili Olarak Yanıtla';
              }

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
                                if (ticket.channel == 'advisor') ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Image.network(
                                        advisor.photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: AppGlass.subtleSurface(context),
                                          child: Icon(
                                            CupertinoIcons.person_fill,
                                            size: 20,
                                            color:
                                                AppGlass.textSecondary(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        headerTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                          color: AppGlass.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        headerSubtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppGlass.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    setModalState(() {
                                      replyAsStaffInDemo = !replyAsStaffInDemo;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppGlass.subtleSurface(context),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppGlass.dividerColor(context),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      replyAsStaffInDemo
                                          ? staffRoleLabel
                                          : 'Müşteri Görünümü',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppGlass.textSecondary(context),
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
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: ticket.messages.length,
                          itemBuilder: (context, index) {
                            final msg = ticket.messages[index];
                            final isMine = replyAsStaffInDemo
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

                            final senderColor = isMine
                                ? (isDark
                                    ? const Color(0xFF141312)
                                        .withValues(alpha: 0.65)
                                    : Colors.white.withValues(alpha: 0.75))
                                : AppGlass.textMuted(context);

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
                                  color: bubbleBg,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                                    bottomRight:
                                        Radius.circular(isMine ? 4 : 18),
                                  ),
                                  border: Border.all(
                                    color: AppGlass.dividerColor(context),
                                    width: 0.6,
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
                                        color: senderColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.35,
                                        color: bubbleText,
                                      ),
                                    ),
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
                                placeholder: replyAsStaffInDemo
                                    ? '$staffRoleLabel mesajınızı yazın...'
                                    : 'Mesajınızı yazın...',
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
                                onSubmitted: (_) {
                                  if (msgController.text.trim().isEmpty) return;
                                  appState.sendTicketMessage(
                                    ticketId: ticket.id,
                                    text: msgController.text.trim(),
                                    isFromAdmin: replyAsStaffInDemo,
                                  );
                                  msgController.clear();
                                },
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
                                  isFromAdmin: replyAsStaffInDemo,
                                );
                                msgController.clear();
                              },
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
    },
  );
}
