import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_state.dart';
import '../../services/portal_repository.dart';
import '../../widgets/website_blurred_background.dart';

class CustomerProjectScreen extends StatelessWidget {
  const CustomerProjectScreen({
    super.key,
    required this.appState,
    this.bottomPadding = 0,
    this.repository,
  });

  final AppState appState;
  final double bottomPadding;
  final PortalRepository? repository;

  @override
  Widget build(BuildContext context) {
    final customer = appState.currentCustomer;
    final isDark = AppGlass.isDark(context);

    if (customer.contractPending) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding + 20),
        children: [
          Text(
            'Evim',
            style: TextStyle(
              color: AppGlass.textPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(18),
            child: const Text(
              'Proje ve konut bilgileriniz sözleşmeniz onaylandığında burada görüntülenecek.',
              style: TextStyle(
                color: Color(0xFFA9A39A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 18, 16, bottomPadding + 20),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evim',
                style: TextStyle(
                  color: AppGlass.textPrimary(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Projeniz ve konut bilgileriniz',
                style: TextStyle(
                  color: AppGlass.textSecondary(context),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 26,
          child: SizedBox(
            height: 218,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  customer.projectImageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: isDark
                        ? const Color(0xFF292522)
                        : const Color(0xFFE5EAF0),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.76),
                      ],
                      stops: const [0.15, 0.48, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Text(
                          'KONUT PROJENİZ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        customer.projectTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.45,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.unitSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48)
                      .withValues(alpha: isDark ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  CupertinoIcons.clock,
                  size: 18,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proje durumu',
                      style: TextStyle(
                        color: AppGlass.textPrimary(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      customer.projectStatus?.trim().isNotEmpty == true
                          ? customer.projectStatus!.trim()
                          : 'Güncel proje bilgilendirmeleri burada paylaşılacak.',
                      style: TextStyle(
                        color: AppGlass.textSecondary(context),
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 11),
          child: Text(
            'Konut bilgileri',
            style: TextStyle(
              color: AppGlass.textPrimary(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
            ),
          ),
        ),
        GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
          child: Column(
            children: [
              _ProjectInfoRow(
                icon: CupertinoIcons.building_2_fill,
                label: 'Proje',
                value: customer.projectTitle,
              ),
              _ProjectInfoRow(
                icon: CupertinoIcons.house,
                label: 'Bağımsız bölüm',
                value: customer.unitSubtitle,
              ),
              _ProjectInfoRow(
                icon: CupertinoIcons.doc_text,
                label: 'Sözleşme numarası',
                value: customer.contractNo,
              ),
              _ProjectInfoRow(
                icon: CupertinoIcons.location,
                label: 'Adres',
                value: customer.address,
                isLast: true,
              ),
            ],
          ),
        ),
        if (customer.contractDocumentPath != null) ...[
          const SizedBox(height: 14),
          GlassCard(
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: CupertinoButton(
              padding: const EdgeInsets.all(16),
              onPressed: repository == null
                  ? null
                  : () async {
                      try {
                        final url = await repository!.getContractDocumentUrl(
                          customer.id,
                        );
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sözleşme açılamadı: $error'),
                            ),
                          );
                        }
                      }
                    },
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_text_fill,
                    color: Color(0xFFE11D48),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      customer.contractDocumentName ?? 'Sözleşme dosyanız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppGlass.textPrimary(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.arrow_up_right_square,
                    color: AppGlass.textMuted(context),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProjectInfoRow extends StatelessWidget {
  const _ProjectInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppGlass.dividerColor(context)),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppGlass.textMuted(context)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppGlass.textMuted(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppGlass.textPrimary(context),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
