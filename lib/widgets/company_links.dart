import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'website_blurred_background.dart';

class CompanyLink {
  const CompanyLink(this.label, this.url, this.icon);

  final String label;
  final String url;
  final IconData icon;
}

const companyPhone = CompanyLink(
  '0 (531) 373 00 54',
  'tel:+905313730054',
  Icons.phone_outlined,
);
const companyEmail = CompanyLink(
  'iletisim@demirturkinsaat.com',
  'mailto:iletisim@demirturkinsaat.com',
  Icons.mail_outline,
);
const companyOffice = CompanyLink(
  'Aziziye Mahallesi, Doğu Karadeniz Caddesi, Ata Sahil Sitesi No. 1, Karasu / Sakarya',
  'https://www.google.com/maps/search/?api=1&query=Aziziye+Mahallesi+Do%C4%9Fu+Karadeniz+Caddesi+Ata+Sahil+Sitesi+No+1+Karasu+Sakarya',
  Icons.location_on_outlined,
);
const companyPrivacy = CompanyLink(
  'Gizlilik Politikası',
  'https://berkantcaliskan.github.io/demirturkapp/privacy.html',
  Icons.privacy_tip_outlined,
);
const _socialLinks = [
  CompanyLink(
    'Instagram',
    'https://www.instagram.com/demirturkinsaat/',
    Icons.photo_camera_outlined,
  ),
  CompanyLink(
    'YouTube',
    'https://www.youtube.com/@demirturkinsaatkarasu',
    Icons.smart_display_outlined,
  ),
  CompanyLink(
    'TikTok',
    'https://www.tiktok.com/@demirturkinsaat',
    Icons.music_note_outlined,
  ),
];
const _sahibindenLinks = [
  CompanyLink(
    'Sahibinden · demirturkyapinsaat',
    'https://demirturkyapinsaat.sahibinden.com/',
    Icons.storefront_outlined,
  ),
  CompanyLink(
    'Sahibinden · karasudemirturk',
    'https://karasudemirturk.sahibinden.com/',
    Icons.storefront_outlined,
  ),
];
const _hepsiemlak = CompanyLink(
  'Hepsiemlak',
  'https://www.hepsiemlak.com/emlak-ofisi/demirturk-yapi-insaat-sanayi-ve-ticaret-limited-si-159946',
  Icons.apartment_outlined,
);

Future<void> openCompanyLink(BuildContext context, CompanyLink link) async {
  try {
    final uri = Uri.parse(link.url);
    final opened = await launchUrl(
      uri,
      mode: uri.scheme == 'https'
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
    if (opened) return;
  } catch (_) {
    // Keep the current screen usable when an external app is unavailable.
  }
  if (!context.mounted) return;
  final message = switch (Uri.parse(link.url).scheme) {
    'tel' => 'Arama ekranı açılamadı. Numaramız ${link.label}.',
    'mailto' => 'E-posta uygulaması açılamadı. Adresimiz ${link.label}.',
    _ => '${link.label} açılamadı. Lütfen tekrar deneyin.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class CompanyLinksFooter extends StatelessWidget {
  const CompanyLinksFooter({super.key});

  Future<void> _chooseStore(BuildContext context) async {
    final selected = await showDialog<CompanyLink>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sahibinden mağazalarımız'),
        children: [
          for (final link in _sahibindenLinks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, link),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(link.label),
              ),
            ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      await openCompanyLink(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 2,
    children: [
      for (final link in _socialLinks) _button(context, link),
      IconButton(
        tooltip: 'Sahibinden mağazalarımız',
        onPressed: () => _chooseStore(context),
        icon: const Icon(Icons.storefront_outlined, size: 21),
        color: AppGlass.textSecondary(context),
      ),
      _button(context, _hepsiemlak),
      _button(context, companyPhone),
      _button(context, companyEmail),
    ],
  );

  Widget _button(BuildContext context, CompanyLink link) => IconButton(
    tooltip: link.label,
    onPressed: () => openCompanyLink(context, link),
    icon: Icon(link.icon, size: 21),
    color: AppGlass.textSecondary(context),
  );
}

class CompanyLinksCard extends StatelessWidget {
  const CompanyLinksCard({super.key});

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      title: Text(
        'Demirtürk bağlantıları',
        style: TextStyle(
          color: AppGlass.textPrimary(context),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      leading: const Icon(Icons.public_outlined),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final link in [..._socialLinks, ..._sahibindenLinks, _hepsiemlak])
          _CompanyLinkTile(link: link),
        const _CompanyLinkTile(link: companyPhone),
        const _CompanyLinkTile(link: companyEmail),
      ],
    ),
  );
}

class CompanyContactCard extends StatelessWidget {
  const CompanyContactCard({super.key});

  @override
  Widget build(BuildContext context) => const GlassCard(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        _CompanyLinkTile(link: companyPhone),
        _CompanyLinkTile(link: companyEmail),
        _CompanyLinkTile(link: companyOffice),
      ],
    ),
  );
}

class _CompanyLinkTile extends StatelessWidget {
  const _CompanyLinkTile({required this.link});

  final CompanyLink link;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(link.icon, color: AppGlass.textSecondary(context)),
    title: Text(
      link.label,
      style: TextStyle(color: AppGlass.textPrimary(context), fontSize: 13),
    ),
    trailing: Icon(
      Icons.chevron_right,
      color: AppGlass.textMuted(context),
      size: 18,
    ),
    onTap: () => openCompanyLink(context, link),
  );
}
