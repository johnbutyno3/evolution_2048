import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../game/screens/evolution_2048_page.dart';
import '../game/models/game_tile.dart';
import '../game/services/audio_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<_ChapterInfo> _chapters = [
    _ChapterInfo(
      titleKey: 'ocean',
      image: 'assets/backgrounds/chapter_01_ocean/ocean_background_01_primordial.jpg',
    ),
    _ChapterInfo(
      titleKey: 'land',
      image: 'assets/backgrounds/chapter_02_land/land_background_01_primordial.jpg',
    ),
    _ChapterInfo(
      titleKey: 'sky',
      image: 'assets/backgrounds/chapter_03_sky/sky_background_01_low_altitude.jpg',
    ),
    _ChapterInfo(
      titleKey: 'history',
      image: 'assets/backgrounds/chapter_04_history/chapter_04_history_bg_01.png',
    ),
    _ChapterInfo(
      titleKey: 'technology',
      image: 'assets/backgrounds/chapter_05_tech/tech_01_electronic_age.png',
    ),
    _ChapterInfo(
      titleKey: 'space',
      image: 'assets/backgrounds/chapter_06_universe/universe_bg_01_origin.jpg',
    ),
  ];

  void _enterChapter(BuildContext context, int index) {
    unawaited(
      AudioManager.instance.playSfx(GameSfx.buttonClick),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Evolution2048Page(
          initialChapter: switch (index) {
            0 => GameChapter.ocean,
            1 => GameChapter.land,
            2 => GameChapter.sky,
            3 => GameChapter.history,
            4 => GameChapter.tech,
            _ => GameChapter.universe,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedChapter = SaveManager.developerAllChapters ? 5 : 0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _chapters[unlockedChapter].image,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopButton(
                        icon: Icons.person_outline,
                        label: 'Player Info',
                        onPressed: () {},
                      ),
                      _TopButton(
                        icon: Icons.storefront_outlined,
                        label: 'Shop',
                        onPressed: () {},
                      ),
                      if (SaveManager.developerMode)
                        _TopButton(
                          icon: Icons.developer_mode,
                          label: 'Developer',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const _DeveloperDialog(),
                            ).then((_) {
                              (context as Element).markNeedsBuild();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rebirth 2048',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 700;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isWide ? 1.45 : 1.15,
                        ),
                        itemCount: _chapters.length,
                        itemBuilder: (context, index) {
                          final unlocked = index <= unlockedChapter;

                          return _ChapterCard(
                            chapter: _chapters[index],
                            unlocked: unlocked,
                            onTap: unlocked
                                ? () => _enterChapter(context, index)
                                : null,
                          );
                        },
                      );
                    },
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

String _localizedChapterTitle(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context)!;
  return switch (key) {
    'ocean' => l10n.chapterOcean,
    'land' => l10n.chapterLand,
    'sky' => l10n.chapterSky,
    'history' => l10n.chapterHistory,
    'technology' => l10n.chapterTechnology,
    'space' => l10n.chapterSpace,
    _ => key,
  };
}

class _ChapterInfo {
  final String titleKey;
  final String image;

  const _ChapterInfo({
    required this.titleKey,
    required this.image,
  });
}

class _ChapterCard extends StatelessWidget {
  final _ChapterInfo chapter;
  final bool unlocked;
  final VoidCallback? onTap;

  const _ChapterCard({
    required this.chapter,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              chapter.image,
              fit: BoxFit.cover,
            ),
            if (!unlocked)
              Container(
                color: Colors.black.withValues(alpha: 0.60),
              ),
            if (!unlocked)
              const Center(
                child: Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  _localizedChapterTitle(context, chapter.titleKey),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _TopButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _DeveloperDialog extends StatefulWidget {
  const _DeveloperDialog();

  @override
  State<_DeveloperDialog> createState() => _DeveloperDialogState();
}

class _DeveloperDialogState extends State<_DeveloperDialog> {
  bool get _allChapters => SaveManager.developerAllChapters;
  bool get _allTools => SaveManager.developerAllTools;
  bool get _unlimitedTools => SaveManager.developerUnlimitedTools;

  Future<void> _setAllChapters(bool value) async {
    await SaveManager.setDeveloperAllChapters(value);
    if (mounted) setState(() {});
  }

  Future<void> _setAllTools(bool value) async {
    await SaveManager.setDeveloperAllTools(value);
    if (mounted) setState(() {});
  }

  Future<void> _setUnlimitedTools(bool value) async {
    await SaveManager.setDeveloperUnlimitedTools(value);
    if (mounted) setState(() {});
  }

  Future<void> _restoreLives() async {
    await LifeManager.restoreFiveLivesForDeveloper();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lives restored to 5')),
      );
      setState(() {});
    }
  }

  void _enterChapter(GameChapter chapter) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Evolution2048Page(initialChapter: chapter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Developer Mode'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Unlock All Chapters'),
                subtitle: const Text('Show Chapters 1–6 as unlocked'),
                value: _allChapters,
                onChanged: _setAllChapters,
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Restore 5 Lives'),
                onTap: _restoreLives,
              ),
              SwitchListTile(
                title: const Text('Unlock All Tools'),
                subtitle: const Text('Make all four tools available'),
                value: _allTools,
                onChanged: _setAllTools,
              ),
              SwitchListTile(
                title: const Text('Unlimited Tools'),
                subtitle: const Text('Tool uses will not decrease'),
                value: _unlimitedTools,
                onChanged: _setUnlimitedTools,
              ),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Enter Chapter',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 1 — Ocean'),
                onTap: () => _enterChapter(GameChapter.ocean),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 2 — Land'),
                onTap: () => _enterChapter(GameChapter.land),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 3 — Sky'),
                onTap: () => _enterChapter(GameChapter.sky),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 4 — History'),
                onTap: () => _enterChapter(GameChapter.history),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 5 — Technology'),
                onTap: () => _enterChapter(GameChapter.tech),
              ),
              ListTile(
                dense: true,
                title: const Text('Chapter 6 — Space'),
                onTap: () => _enterChapter(GameChapter.universe),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
