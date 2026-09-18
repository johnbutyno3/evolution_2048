import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../game/models/creature.dart';
import '../services/creature_collection_service.dart';
import '../services/player_profile_service.dart';

import '../game/services/audio_manager.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import 'login_register_page.dart';
import 'shop_page.dart';
import 'feedback_page.dart';

String _p(BuildContext context, String en, String zh) => Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Personal', '個人資訊'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline),
              ),
              title: Text(_p(context, 'Player Basic Information', '玩家基本資料')),
              subtitle: Text(_p(context, 'Avatar, Player Name, Player ID and account information', '頭像、玩家名稱、玩家 ID 與帳號資訊')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerInfoPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            icon: Icons.menu_book_outlined,
            title: _p(context, 'Creature Collection', '生物圖鑑'),
            subtitle: _p(context, 'Discovered life forms', '已發現的生命形態'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CollectionPage())),
          ),
          _SectionCard(
            icon: Icons.settings_outlined,
            title: _p(context, 'Settings', '設定'),
            subtitle: _p(context, 'Music, sound effects, vibration and language', '音樂、音效、震動與語言'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          _SectionCard(
            icon: Icons.help_outline,
            title: _p(context, 'Game Guide', '遊戲說明'),
            subtitle: _p(context, 'Rules and how to play', '遊戲規則與玩法'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GameGuidePage())),
          ),
          _SectionCard(
            icon: Icons.info_outline,
            title: _p(context, 'Version Info', '版本資訊'),
            subtitle: _p(context, 'App and game version', 'APP 與遊戲版本'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const VersionInfoPage())),
          ),
          _SectionCard(
            icon: Icons.feedback_outlined,
            title: _p(context, 'Messages / Feedback', '留言 / 意見回饋'),
            subtitle: _p(context, 'Send questions, suggestions or bug reports', '傳送問題、建議或錯誤回報'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackPage()),
            ),
          ),
          _SectionCard(
            icon: Icons.info_outline,
            title: _p(context, 'About Game', '關於遊戲'),
            subtitle: _p(context, 'Creator, music, assets and third-party services', '製作者、音樂、素材與第三方服務資訊'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutGamePage()),
            ),
          ),
          const SizedBox(height: 12),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(_p(context, 'Log Out', '登出')),
              onTap: () => _logout(context),
            ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_p(context, 'Log Out', '登出')),
          content: const Text(
            'Are you sure you want to log out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
      (route) => false,
    );
  }
}

class PlayerInfoPage extends StatefulWidget {
  const PlayerInfoPage({super.key});

  @override
  State<PlayerInfoPage> createState() => _PlayerInfoPageState();
}

class _PlayerInfoPageState extends State<PlayerInfoPage> {
  static const List<String> _avatarAssets = [
    // Original / White
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

    // Black / African
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

    // Asian
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

  late final TextEditingController _nameController;
  late int _avatarIndex;
  String _playerId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _avatarIndex = 0;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      await PlayerProfileService.ensureProfile();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      final firebaseAvatarIndex = data?['avatarIndex'];
      if (firebaseAvatarIndex is num) {
        _avatarIndex = firebaseAvatarIndex.toInt().clamp(0, 53);
        await SaveManager.saveAvatarIndex(_avatarIndex);
      }

      final firebaseName = data?['playerName'];

      if (firebaseName is String &&
          firebaseName.trim().isNotEmpty &&
          firebaseName.trim().toUpperCase() != 'PLAYER') {
        final cleanName = firebaseName.trim();
        _nameController.text = cleanName;
        await SaveManager.saveProfile(name: cleanName);
      }

      final firebasePlayerId = data?['playerId'];
      if (firebasePlayerId is String && firebasePlayerId.isNotEmpty) {
        _playerId = firebasePlayerId;
        await SaveManager.savePlayerId(firebasePlayerId);
      }

      if (!context.mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!context.mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player name cannot be empty.')),
      );
      return;
    }

    try {
      final success = await PlayerProfileService.updatePlayerName(name);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Player name updated.' : 'Unable to update player name.',
          ),
        ),
      );
    } on PlayerProfileException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update player name: $error')),
      );
    }
  }

  Future<void> _selectAvatar(int index) async {
    await PlayerProfileService.updateAvatarIndex(index);
    if (!context.mounted) return;
    setState(() => _avatarIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final membership = LifeManager.membership;

    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Player Info', '玩家資料'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _AvatarCircle(index: _avatarIndex, size: 104)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _p(context, 'Choose your avatar', '選擇頭像'),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          _AvatarSheetPicker(
            selectedIndex: _avatarIndex,
            onSelected: _selectAvatar,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: _p(context, 'Player Name', '玩家名稱'),
              border: OutlineInputBorder(),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveName,
              child: Text(_p(context, 'Save', '儲存')),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(_p(context, 'Player ID', '玩家 ID')),
              subtitle: Text(
                _loading
                    ? 'Loading...'
                    : (_playerId.isEmpty ? 'Not available' : _playerId),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(_p(context, 'Membership', '會員資格')),
              subtitle: Text(
                membership == 'golden'
                    ? 'Golden Member'
                    : membership == 'premium'
                    ? 'Premium Member'
                    : 'General Member',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ShopPage()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSheetPicker extends StatelessWidget {
  const _AvatarSheetPicker({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _PlayerInfoPageState._avatarAssets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final selected = index == selectedIndex;

        return Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              onSelected(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: _AvatarCircle(index: index, size: double.infinity),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.index, required this.size});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(
      0,
      _PlayerInfoPageState._avatarAssets.length - 1,
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _PlayerInfoPageState._avatarAssets[safeIndex],
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) {
            return const ColoredBox(
              color: Colors.white,
              child: Icon(Icons.person, size: 40),
            );
          },
        ),
      ),
    );
  }
}

class EvolutionProgressPage extends StatelessWidget {
  const EvolutionProgressPage({super.key});

  static const chapters = [
    ('Ocean', 12),
    ('Land', 13),
    ('Sky', 14),
    ('History', 15),
    ('Technology', 16),
    ('Space', 17),
  ];

  @override
  Widget build(BuildContext context) {
    final save = SaveManager.loadCached();
    final currentChapterName = save?['chapter'] as String?;
    final chapterComplete = save?['chapterComplete'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Evolution Progress', '進化進度'))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chapters.length,
        itemBuilder: (_, index) {
          final chapter = chapters[index];
          final isCurrent = chapter.$1.toLowerCase() == currentChapterName;
          final isCompleted = index < _chapterIndex(currentChapterName);

          final status = isCompleted
              ? 'Completed'
              : isCurrent && chapterComplete
              ? 'Chapter Complete'
              : isCurrent
              ? 'Current Chapter'
              : 'Locked';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(chapter.$1),
              subtitle: Text('${chapter.$2} stages · $status'),
              trailing: isCompleted
                  ? const Icon(Icons.check_circle_outline)
                  : isCurrent
                  ? const Icon(Icons.play_arrow)
                  : const Icon(Icons.lock_outline),
            ),
          );
        },
      ),
    );
  }

  int _chapterIndex(String? chapter) {
    const names = ['ocean', 'land', 'sky', 'history', 'tech', 'universe'];

    final index = names.indexOf(chapter ?? '');
    return index < 0 ? 0 : index;
  }
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  bool _loading = true;
  int _selectedChapter = 0;

  final Map<String, Set<int>> _discovered = {};

  static const List<String> _chapterKeys = [
    'ocean',
    'land',
    'sky',
    'history',
    'technology',
    'space',
  ];

  static const List<String> _chapterNames = [
    'Chapter 1 · Ocean',
    'Chapter 2 · Land',
    'Chapter 3 · Sky',
    'Chapter 4 · History',
    'Chapter 5 · Technology',
    'Chapter 6 · Space',
  ];

  static const List<String> _chapterShortNames = [
    'Ocean',
    'Land',
    'Sky',
    'History',
    'Technology',
    'Space',
  ];

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return;

      setState(() {
        _discovered.clear();
        _loading = false;
      });
      return;
    }

    final result = <String, Set<int>>{};
    try {
      for (final chapterKey in _chapterKeys) {
        result[chapterKey] = await CreatureCollectionService.loadDiscovered(
          chapterKey,
        );
      }
    } catch (_) {
      result.clear();
    }

    if (!context.mounted) return;
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      setState(() {
        _discovered.clear();
        _loading = false;
      });
      return;
    }

    setState(() {
      _discovered
        ..clear()
        ..addAll(result);
      _loading = false;
    });
  }

  List<Creature> _creaturesForChapter(int chapter) {
    switch (chapter) {
      case 0:
        return Creature.chapter1Ocean;
      case 1:
        return Creature.chapter2Land;
      case 2:
        return Creature.chapter3Sky;
      case 3:
        return Creature.chapter4History;
      case 4:
        return Creature.chapter5Tech;
      case 5:
        return Creature.chapter6Universe;
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatures = _creaturesForChapter(_selectedChapter);
    final chapterKey = _chapterKeys[_selectedChapter];
    final discovered = _discovered[chapterKey] ?? <int>{};

    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Creature Collection', '生物圖鑑'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCollection,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _CollectionSummary(
                        chapterName: _chapterNames[_selectedChapter],
                        discovered: discovered.length,
                        total: creatures.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: _chapterShortNames.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(_chapterShortNames[index]),
                              selected: index == _selectedChapter,
                              onSelected: (_) {
                                setState(() {
                                  _selectedChapter = index;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final creature = creatures[index];

                        return _CreatureCollectionCard(
                          creature: creature,
                          discovered: discovered.contains(creature.value),
                        );
                      }, childCount: creatures.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.76,
                          ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({
    required this.chapterName,
    required this.discovered,
    required this.total,
  });

  final String chapterName;
  final int discovered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : discovered / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$discovered / $total discovered'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatureCollectionCard extends StatelessWidget {
  const _CreatureCollectionCard({
    required this.creature,
    required this.discovered,
  });

  final Creature creature;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: discovered
            ? Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      creature.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creature.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${creature.value}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.lock_outline,
                        size: 42,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Undiscovered',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stage ${creature.stage}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class GoldPage extends StatelessWidget {
  const GoldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: GoldManager.initialize(),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(title: const Text('Gold')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.monetization_on, size: 56),
                      const SizedBox(height: 12),
                      const Text(
                        'Gold Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${GoldManager.balance}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Lifetime Spent'),
                  trailing: Text('${GoldManager.lifetimeSpent} Gold'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Gold is used for lives and tool purchases.',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AudioManager get _audio => AudioManager.instance;

  @override
  void initState() {
    super.initState();
    _audio.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(_p(context, 'Background Music', '背景音樂')),
            value: _audio.musicEnabled,
            onChanged: (value) async {
              await _audio.setMusicEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: Text(_p(context, 'Music Volume', '音樂音量')),
            subtitle: Slider(
              value: _audio.musicVolume,
              onChanged: (value) async {
                await _audio.setMusicVolume(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          SwitchListTile(
            title: Text(_p(context, 'Sound Effects', '音效')),
            value: _audio.sfxEnabled,
            onChanged: (value) async {
              await _audio.setSfxEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: Text(_p(context, 'Sound Effects Volume', '音效音量')),
            subtitle: Slider(
              value: _audio.sfxVolume,
              onChanged: (value) async {
                await _audio.setSfxVolume(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SwitchListTile(
            title: Text('Vibration'),
            value: true,
            onChanged: null,
          ),
          ListTile(
            title: Text(_p(context, 'Language', '語言')),
            trailing: DropdownButton<String>(
              value: SaveManager.localeCode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'zh', child: Text('繁體中文')),
              ],
              onChanged: (value) {
                if (value != null) {
                  SaveManager.saveLocaleCode(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GameGuidePage extends StatelessWidget {
  const GameGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Game Guide', '遊戲說明'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _p(context, 'How to Play', '遊戲玩法'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Use the 4×4 board to move and merge identical life forms into the next evolution stage.',
          ),
          SizedBox(height: 24),
          Text(
            _p(context, 'Six Chapters', '六大章節'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Ocean → Land → Sky → History → Technology → Space'),
          SizedBox(height: 24),
          Text(
            _p(context, 'Resources', '資源'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Lives are used for gameplay attempts. Gold can be used to purchase additional lives and tools. Tool inventory is cumulative across chapters.',
          ),
        ],
      ),
    );
  }
}

class VersionInfoPage extends StatelessWidget {
  const VersionInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_p(context, 'Version Info', '版本資訊'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(title: Text(_p(context, 'App', 'APP')), subtitle: Text('Rebirth 2048')),
          ListTile(
            title: Text(_p(context, 'Game Version', '遊戲版本')),
            subtitle: Text(_p(context, 'Current development build', '目前開發版本')),
          ),
          ListTile(
            title: Text(_p(context, 'Build', '建置版本')),
            subtitle: Text(
              _p(context, 'Read from the platform package in the release build.', '正式發行版將由平台套件讀取版本資訊。'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


class AboutGamePage extends StatelessWidget {
  const AboutGamePage({super.key});
  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(zh ? '關於遊戲' : 'About Game')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Rebirth 2048', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          Text(zh ? '製作資訊' : 'Creator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(zh ? '遊戲製作者：Rebirth 2048 開發團隊' : 'Game creator: Rebirth 2048 development team'),
          const SizedBox(height: 18),
          Text(zh ? '音樂與音效來源' : 'Music & Sound Sources', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(zh ? '音樂與音效資產及其來源，依專案 assets/audio/music.txt 與正式授權紀錄確認。' : 'Music and sound assets and their sources are documented in the project audio source record and final attribution list.'),
          const SizedBox(height: 18),
          Text(zh ? '美術與第三方服務' : 'Artwork & Third-party Services', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(zh ? '美術素材、Firebase、Flutter 及其他第三方套件的授權與來源，將以正式發行版本的授權清單為準。' : 'Artwork, Firebase, Flutter and third-party package licenses and sources will follow the final release attribution list.'),
          const SizedBox(height: 18),
          Text(zh ? '版本' : 'Version', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Development Build'),
        ],
      ),
    );
  }
}
