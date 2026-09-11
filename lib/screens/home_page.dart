import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../game/screens/evolution_2048_page.dart';
import '../game/models/game_tile.dart';
import '../game/services/audio_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../services/player_progress_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

  static const List<_ChapterInfo> chapters = [
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
}

class _HomePageState extends State<HomePage> {
  final PlayerProgressService _progress = PlayerProgressService.instance;
  bool _loadingProgress = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProgress());
  }

  Future<void> _loadProgress() async {
    await _progress.refresh();
    if (!mounted) return;
    setState(() => _loadingProgress = false);
  }

  void _enterChapter(BuildContext context, int index) {
    if (!_progress.isChapterUnlocked(index)) {
      return;
    }

    unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick));

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
    final unlockedChapter = _progress.unlockedChapterIndex;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              HomePage.chapters[unlockedChapter].image,
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
                            );
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
                  child: _loadingProgress
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 700;

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 3 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: isWide ? 1.45 : 1.15,
                              ),
                              itemCount: HomePage.chapters.length,
                              itemBuilder: (context, index) {
                                final unlocked =
                                    _progress.isChapterUnlocked(index);

                                return _ChapterCard(
                                  chapter: HomePage.chapters[index],
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
  bool get _allTools => SaveManager.developerAllTools;
  bool get _unlimitedTools => SaveManager.developerUnlimitedTools;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Developer Mode'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Restore 5 Lives'),
              onTap: _restoreLives,
            ),
            SwitchListTile(
              title: const Text('Unlock All Tools'),
              subtitle: const Text('Testing only'),
              value: _allTools,
              onChanged: _setAllTools,
            ),
            SwitchListTile(
              title: const Text('Unlimited Tools'),
              subtitle: const Text('Testing only'),
              value: _unlimitedTools,
              onChanged: _setUnlimitedTools,
            ),
          ],
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
