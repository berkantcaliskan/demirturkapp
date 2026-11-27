import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/website_blurred_background.dart';

class CustomerProjectShowcase extends StatefulWidget {
  const CustomerProjectShowcase({
    super.key,
    required this.bottomPadding,
    this.onContact,
  });

  final double bottomPadding;
  final VoidCallback? onContact;

  @override
  State<CustomerProjectShowcase> createState() =>
      _CustomerProjectShowcaseState();
}

class _CustomerProjectShowcaseState extends State<CustomerProjectShowcase>
    with WidgetsBindingObserver {
  static const _coverDuration = Duration(seconds: 5);
  final _coverPhotos = List<int>.filled(_showcaseProjects.length, 0);
  Timer? _coverTimer;
  int _nextCover = 0;
  bool _animationsEnabled = false;
  bool _appActive = true;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsEnabled =
        TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    _updateCoverTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updateCoverTimer();
  }

  void _updateCoverTimer() {
    if (!_animationsEnabled || !_appActive || _detailsOpen) {
      _coverTimer?.cancel();
      _coverTimer = null;
      return;
    }
    if (_coverTimer != null) return;
    _coverTimer = Timer(_coverDuration, () {
      _advanceCover();
      _coverTimer = Timer.periodic(
        Duration(
          microseconds:
              _coverDuration.inMicroseconds ~/ _showcaseProjects.length,
        ),
        (_) => _advanceCover(),
      );
    });
  }

  void _advanceCover() {
    setState(() {
      final project = _showcaseProjects[_nextCover];
      _coverPhotos[_nextCover] =
          (_coverPhotos[_nextCover] + 1) % project.photoCount;
      _nextCover = (_nextCover + 1) % _showcaseProjects.length;
    });
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openProject(
    BuildContext context,
    _ShowcaseProject project,
  ) async {
    _detailsOpen = true;
    _updateCoverTimer();
    try {
      final contactRequested = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _ShowcaseProjectPage(
            project: project,
            showContact: widget.onContact != null,
          ),
        ),
      );
      if (contactRequested == true && mounted) widget.onContact?.call();
    } finally {
      if (mounted) {
        _detailsOpen = false;
        _updateCoverTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('project-showcase'),
      padding: EdgeInsets.fromLTRB(18, 12, 18, widget.bottomPadding + 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 6, 3, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projelerimiz',
                        style: _projectHeading(
                          context,
                          42,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Karasu’daki Demirtürk projelerini keşfedin.',
                        style: TextStyle(
                          color: AppGlass.textSecondary(context),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var index = 0; index < _showcaseProjects.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: _ProjectCard(
                      key: ValueKey(
                        'project-card-${_showcaseProjects[index].assetName}',
                      ),
                      project: _showcaseProjects[index],
                      photoIndex: _coverPhotos[index],
                      onTap: () =>
                          _openProject(context, _showcaseProjects[index]),
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

TextStyle _projectHeading(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w700,
}) => TextStyle(
  fontFamily: 'Plus Jakarta Sans',
  fontWeight: weight,
  fontSize: size,
  height: 1.03,
  letterSpacing: -0.65,
  color: AppGlass.textPrimary(context),
);

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    super.key,
    required this.project,
    required this.photoIndex,
    required this.onTap,
  });

  final _ShowcaseProject project;
  final int photoIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(25),
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: AspectRatio(
          aspectRatio: 1.55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _ProjectPhoto(
                  key: ValueKey(photoIndex),
                  project: project,
                  index: photoIndex,
                  fit: BoxFit.cover,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x22000000),
                      Color(0xE612100F),
                    ],
                    stops: [0.22, 0.46, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 15,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.location,
                            style: const TextStyle(
                              color: Color(0xFFEDE5DC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project.title,
                            style: _projectHeading(
                              context,
                              29,
                            ).copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xEEFBF6EE),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          CupertinoIcons.arrow_right,
                          color: Color(0xFF231E1B),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseProjectPage extends StatefulWidget {
  const _ShowcaseProjectPage({
    required this.project,
    required this.showContact,
  });

  final _ShowcaseProject project;
  final bool showContact;

  @override
  State<_ShowcaseProjectPage> createState() => _ShowcaseProjectPageState();
}

class _ShowcaseProjectPageState extends State<_ShowcaseProjectPage> {
  final _gallery = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isDark = AppGlass.isDark(context);
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF161311)
          : const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppGlass.textPrimary(context),
        title: const Text('Projelerimiz', style: TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: AspectRatio(
                        aspectRatio: 1.52,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _gallery,
                              itemCount: project.photoCount,
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              itemBuilder: (_, index) => _ProjectPhoto(
                                project: project,
                                index: index,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 11,
                              right: 12,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: Color(0xB31C1815),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      '${_photoIndex + 1} / ${project.photoCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(project.photoCount, (index) {
                        final selected = _photoIndex == index;
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 9,
                          ),
                          minimumSize: const Size(44, 44),
                          onPressed: () => _gallery.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          ),
                          child: Semantics(
                            label: 'Fotoğraf ${index + 1}',
                            selected: selected,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selected ? 19 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: selected
                                    ? const Color(0xFFE11D48)
                                    : AppGlass.textMuted(context),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Text(
                      project.title,
                      style: _projectHeading(
                        context,
                        38,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location,
                          size: 15,
                          color: Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            project.location,
                            style: TextStyle(
                              color: AppGlass.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      project.description,
                      style: TextStyle(
                        color: AppGlass.textSecondary(context),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 17),
                    GlassCard(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          for (final feature in project.features)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.check_mark,
                                  size: 14,
                                  color: Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      color: AppGlass.textPrimary(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (widget.showContact) ...[
                      const SizedBox(height: 18),
                      IosGlassButton(
                        icon: CupertinoIcons.chat_bubble,
                        label: 'Bilgi alın',
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectPhoto extends StatelessWidget {
  const _ProjectPhoto({
    super.key,
    required this.project,
    required this.index,
    required this.fit,
  });

  final _ShowcaseProject project;
  final int index;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/vitrin-${project.assetName}-${index + 1}.jpg',
    semanticLabel: '${project.title}, fotoğraf ${index + 1}',
    fit: fit,
    alignment: Alignment.center,
    errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF292522)),
  );
}

class _ShowcaseProject {
  const _ShowcaseProject({
    required this.title,
    required this.location,
    required this.assetName,
    required this.photoCount,
    required this.description,
    required this.features,
  });

  final String title;
  final String location;
  final String assetName;
  final int photoCount;
  final String description;
  final List<String> features;
}

const _showcaseProjects = [
  _ShowcaseProject(
    title: 'Yenişehir',
    location: 'Yalı Mahallesi · Karasu',
    assetName: 'yenisehir',
    photoCount: 3,
    description: 'Yenişehir etapları, Karasu’nun Yalı Mahallesi’nde ortak açık alanlar etrafında şekilleniyor. Etaplara göre 1+1 ve 2+1 daire seçenekleri, havuz ve peyzaj alanları bulunuyor.',
    features: ['1+1 ve 2+1 seçenekleri', 'Havuz', 'Peyzaj alanları'],
  ),
  _ShowcaseProject(
    title: 'Asel Doğa Evleri',
    location: 'Aziziye Mahallesi · Karasu',
    assetName: 'asel',
    photoCount: 3,
    description: 'Aziziye’deki Asel Doğa Evleri, 2+1 daireleri ve ortak havuzuyla butik bir site düzeni sunuyor. Bahçe katlarında müstakil bahçe, üst katlarda seyir terasları öne çıkıyor.',
    features: ['2+1 daireler', 'Ortak havuz', 'Bahçe ve teras seçenekleri'],
  ),
  _ShowcaseProject(
    title: 'Asel Doğa Evleri 3',
    location: 'Aziziye Mahallesi · Karasu',
    assetName: 'asel3',
    photoCount: 3,
    description: 'Asel Doğa Evleri 3, Karasu’nun Aziziye Mahallesi’nde 2+1 daireleri, ortak havuzu ve peyzajlı bahçesiyle üç katlı bir konut projesi. Balkonlar ve bahçedeki oturma alanları günlük yaşama açık hava alanları katıyor.',
    features: [
      '2+1 daireler',
      'Ortak havuz',
      'Peyzajlı bahçe',
      'Balkonlu daireler',
    ],
  ),
  _ShowcaseProject(
    title: 'Asel Doğa Evleri 4',
    location: 'Karasu · Sakarya',
    assetName: 'asel4',
    photoCount: 3,
    description: 'Asel Doğa Evleri 4, 1+1 ve 2+1 daire seçeneklerini ortak havuz ve peyzajlı bahçeyle bir araya getiriyor. Üç katlı projede A ve B olmak üzere iki ayrı giriş, balkonlu daireler ve açık hava oturma alanları bulunuyor.',
    features: [
      '1+1 ve 2+1 seçenekleri',
      'Ortak havuz',
      'Peyzajlı bahçe',
      'İki ayrı giriş',
    ],
  ),
  _ShowcaseProject(
    title: 'Almina 2',
    location: 'Yalı Mahallesi · Karasu',
    assetName: 'almina',
    photoCount: 3,
    description: 'Almina 2, Karasu’nun Yalı Mahallesi’nde çarşıya yakın konumlanan bir konut projesi. 2+1 daire seçeneklerinin yanı sıra bahçe katlarında özel açık alanlar bulunuyor.',
    features: ['2+1 daireler', 'Bahçe katı seçenekleri', 'Çarşıya yakın konum'],
  ),
];
