import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../game/screens/evolution_2048_page.dart';
import '../game/models/game_tile.dart';
import '../game/services/audio_manager.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';
import '../game/services/save_manager.dart';
import '../services/player_profile_service.dart';
import '../services/player_progress_service.dart';
import 'personal_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
  static const chapters = [
    ChapterInfo(
      titleKey: 'ocean',
      image:
          'assets/backgrounds/chapter_01_ocean/ocean_background_01_primordial.jpg',
    ),
    ChapterInfo(
      titleKey: 'land',
      image:
          'assets/backgrounds/chapter_02_land/land_background_01_primordial.jpg',
    ),
    ChapterInfo(
      titleKey: 'sky',
      image:
          'assets/backgrounds/chapter_03_sky/sky_background_01_low_altitude.jpg',
    ),
    ChapterInfo(
      titleKey: 'history',
      image:
          'assets/backgrounds/chapter_04_history/chapter_04_history_bg_01.png',
    ),
    ChapterInfo(
      titleKey: 'technology',
      image: 'assets/backgrounds/chapter_05_tech/tech_01_electronic_age.png',
    ),
    ChapterInfo(
      titleKey: 'space',
      image: 'assets/backgrounds/chapter_06_universe/universe_bg_01_origin.jpg',
    ),
  ];
}

const List<String> _homeAvatarAssets = [
  // Original / White — canonical order shared with Player Info.
  'assets/avatars/avatar_ancient_young_male.png',
  'assets/avatars/avatar_ancient_young_female.png',
  'assets/avatars/avatar_ancient_middle_male.png',
  'assets/avatars/avatar_ancient_middle_female.png',
  'assets/avatars/avatar_ancient_elder_male.png',
  'assets/avatars/avatar_ancient_elder_female.png',
  'assets/avatars/avatar_modern_young_male.png',
  'assets/avatars/avatar_modern_young_female.png',
  'assets/avatars/avatar_modern_middle_male.png',
  'assets/avatars/avatar_modern_middle_female.png',
  'assets/avatars/avatar_modern_elder_male.png',
  'assets/avatars/avatar_modern_elder_female.png',
  'assets/avatars/avatar_future_young_male.png',
  'assets/avatars/avatar_future_young_female.png',
  'assets/avatars/avatar_future_middle_male.png',
  'assets/avatars/avatar_future_middle_female.png',
  'assets/avatars/avatar_future_elder_male.png',
  'assets/avatars/avatar_future_elder_female.png',

  // Black / African.
  'assets/avatars/black_avatar_ancient_young_male.png',
  'assets/avatars/black_avatar_ancient_young_female.png',
  'assets/avatars/black_avatar_ancient_middle_male.png',
  'assets/avatars/black_avatar_ancient_middle_female.png',
  'assets/avatars/black_avatar_ancient_elder_male.png',
  'assets/avatars/black_avatar_ancient_elder_female.png',
  'assets/avatars/black_avatar_modern_young_male.png',
  'assets/avatars/black_avatar_modern_young_female.png',
  'assets/avatars/black_avatar_modern_middle_male.png',
  'assets/avatars/black_avatar_modern_middle_female.png',
  'assets/avatars/black_avatar_modern_elder_male.png',
  'assets/avatars/black_avatar_modern_elder_female.png',
  'assets/avatars/black_avatar_future_young_male.png',
  'assets/avatars/black_avatar_future_young_female.png',
  'assets/avatars/black_avatar_future_middle_male.png',
  'assets/avatars/black_avatar_future_middle_female.png',
  'assets/avatars/black_avatar_future_elder_male.png',
  'assets/avatars/black_avatar_future_elder_female.png',

  // Asian.
  'assets/avatars/asian_avatar_ancient_young_male.png',
  'assets/avatars/asian_avatar_ancient_young_female.png',
  'assets/avatars/asian_avatar_ancient_middle_male.png',
  'assets/avatars/asian_avatar_ancient_middle_female.png',
  'assets/avatars/asian_avatar_ancient_elder_male.png',
  'assets/avatars/asian_avatar_ancient_elder_female.png',
  'assets/avatars/asian_avatar_modern_young_male.png',
  'assets/avatars/asian_avatar_modern_young_female.png',
  'assets/avatars/asian_avatar_modern_middle_male.png',
  'assets/avatars/asian_avatar_modern_middle_female.png',
  'assets/avatars/asian_avatar_modern_elder_male.png',
  'assets/avatars/asian_avatar_modern_elder_female.png',
  'assets/avatars/asian_avatar_future_young_male.png',
  'assets/avatars/asian_avatar_future_young_female.png',
  'assets/avatars/asian_avatar_future_middle_male.png',
  'assets/avatars/asian_avatar_future_middle_female.png',
  'assets/avatars/asian_avatar_future_elder_male.png',
  'assets/avatars/asian_avatar_future_elder_female.png',
];

class _HomePageState extends State<HomePage> {
  final _progress = PlayerProgressService.instance;
  bool _loading = true;
  bool _enterInProgress = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await Future.wait([
      PlayerProfileService.ensureProfile().catchError((_) => null),
      LifeManager.initialize().catchError((_) => null),
      GoldManager.initialize().catchError((_) => null),
      ToolManager.refreshInventory().catchError((_) => null),
      _progress.refresh().catchError((_) => null),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openPersonal() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PersonalPage()));
    if (mounted) setState(() {});
  }

  Future<void> _enter(BuildContext context, int index) async {
    if (_enterInProgress) return;
    if (!_progress.isChapterUnlocked(index)) return;
    _enterInProgress = true;
    final unfinishedChapter = SaveManager.unfinishedChapter;
    if (unfinishedChapter != null &&
        unfinishedChapter != _chapterKey(index)) {
      return;
    }

    // The server can still own an active session even when its local board
    // snapshot is missing/stale. Never let Home open a different chapter in
    // that state; Evolution2048Page would otherwise reject the entry only
    // after navigation and leave the user on a dead game screen.
    final activeChapter = _progress.activeGameChapterIndex;
    if (_progress.activeGameSessionId != null &&
        activeChapter != null &&
        activeChapter != index) {
      return;
    }
    unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick));
    await Navigator.of(context).push(
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

    // The game settles Life and active-session state before returning Home.
    // Refresh the authoritative server state so the Home header never keeps
    // showing the pre-entry Life balance after a game session ends.
    await Future.wait([
      _progress.refresh().catchError((_) => null),
      LifeManager.refreshFromServer().catchError((_) => null),
      ToolManager.refreshInventory().catchError((_) => null),
    ]);
    if (mounted) setState(() {});
    _enterInProgress = false;
  }

  String _chapterKey(int index) => HomePage.chapters[index].titleKey == 'technology'
      ? 'tech'
      : HomePage.chapters[index].titleKey == 'space'
          ? 'universe'
          : HomePage.chapters[index].titleKey;

  @override
  Widget build(BuildContext context) {
    final unlocked = _progress.unlockedChapterIndex
        .clamp(0, HomePage.chapters.length - 1)
        .toInt();

    final avatarIndex = SaveManager.avatarIndex.clamp(
      0,
      _homeAvatarAssets.length - 1,
    );
    final avatarAsset = _homeAvatarAssets[avatarIndex];
    final l = AppLocalizations.of(context)!;
    final playerName = SaveManager.profileName ?? l.notAvailable;
    final playerId = SaveManager.playerId ?? l.notAvailable;
    final membership = switch (LifeManager.membership) {
      'premium' => l.premiumMember,
      'golden' => l.goldenMember,
      _ => l.generalMember,
    };
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              HomePage.chapters[unlocked].image,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .30),
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
                      InkWell(
                        onTap: _openPersonal,
                        borderRadius: BorderRadius.circular(26),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.asset(
                              avatarAsset,
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            playerId,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            membership,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LifeManager.isGoldenMember
                                ? '${l.life}: ∞'
                                : '${l.life}: ${LifeManager.lifeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed('/shop');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${l.gold}: ${GoldManager.balance}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _TopButton(
                        icon: Icons.storefront_outlined,
                        label: l.shop,
                        onPressed: () {
                          Navigator.of(context).pushNamed('/shop');
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
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: constraints.maxWidth >= 700
                                        ? 3
                                        : 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio:
                                        constraints.maxWidth >= 700
                                        ? 1.45
                                        : 1.15,
                                  ),
                              itemCount: HomePage.chapters.length,
                              itemBuilder: (context, index) {
                                final serverOpen = _progress.isChapterUnlocked(index);
                                final unfinishedChapter = SaveManager.unfinishedChapter;
                                final open = serverOpen &&
                                    (unfinishedChapter == null ||
                                        unfinishedChapter == _chapterKey(index));

                                final highestValue =
                                    _progress.chapterHighestValue(index);
                                final score = _progress.chapterScore(index);

                                return _ChapterCard(
                                  chapter: HomePage.chapters[index],
                                  unlocked: open,
                                  highestValue: highestValue,
                                  score: score,
                                  onTap: open
                                      ? () => _enter(context, index)
                                      : null,
                                  hasUnfinishedOtherChapter: serverOpen &&
                                      unfinishedChapter != null &&
                                      unfinishedChapter != _chapterKey(index),
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
  final l = AppLocalizations.of(context)!;
  return switch (key) {
    'ocean' => l.chapterOcean,
    'land' => l.chapterLand,
    'sky' => l.chapterSky,
    'history' => l.chapterHistory,
    'technology' => l.chapterTechnology,
    'space' => l.chapterSpace,
    _ => key,
  };
}

class ChapterInfo {
  final String titleKey, image;
  const ChapterInfo({required this.titleKey, required this.image});
}

class _ChapterCard extends StatelessWidget {
  final ChapterInfo chapter;
  final bool unlocked;
  final int highestValue;
  final int score;
  final VoidCallback? onTap;
  final bool hasUnfinishedOtherChapter;
  const _ChapterCard({
    required this.chapter,
    required this.unlocked,
    required this.highestValue,
    required this.score,
    required this.onTap,
    this.hasUnfinishedOtherChapter = false,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(chapter.image, fit: BoxFit.cover),
          if (!unlocked) Container(color: Colors.black.withValues(alpha: .60)),
          if (!unlocked)
            Center(
              child: Icon(
                hasUnfinishedOtherChapter ? Icons.play_circle_outline : Icons.lock,
                color: Colors.white,
                size: 52,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.black.withValues(alpha: .55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _localizedChapterTitle(context, chapter.titleKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$highestValue / $score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}
