import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../game/models/creature.dart';
import '../services/creature_collection_service.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/audio_manager.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../game/services/tool_manager.dart';
import 'login_register_page.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = SaveManager.profileName?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Personal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.person_outline,
            title: 'Player Info',
            subtitle: name?.isNotEmpty == true ? name! : 'Player profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlayerInfoPage()),
            ),
          ),
          _SectionCard(
            icon: Icons.auto_awesome,
            title: 'Evolution Progress',
            subtitle: 'Six chapters and current progress',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EvolutionProgressPage(),
              ),
            ),
          ),
          _SectionCard(
            icon: Icons.menu_book_outlined,
            title: 'Creature Collection',
            subtitle: 'Discovered life forms',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CollectionPage()),
            ),
          ),
          _SectionCard(
            icon: Icons.monetization_on_outlined,
            title: 'Gold',
            subtitle: 'Balance and spending history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoldPage()),
            ),
          ),
          _SectionCard(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Music, sound effects, vibration and language',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          _SectionCard(
            icon: Icons.help_outline,
            title: 'Game Guide',
            subtitle: 'Rules and how to play',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameGuidePage()),
            ),
          ),
          _SectionCard(
            icon: Icons.info_outline,
            title: 'Version Info',
            subtitle: 'App and game version',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VersionInfoPage()),
            ),
          ),
          const SizedBox(height: 12),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log Out'),
              onTap: () => _logout(context),
            ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
      (_) => false,
    );
  }
}

class PlayerInfoPage extends StatefulWidget {
  const PlayerInfoPage({super.key});

  @override
  State<PlayerInfoPage> createState() => _PlayerInfoPageState();
}

class _PlayerInfoPageState extends State<PlayerInfoPage> {
  late final TextEditingController _nameController;
  late int _avatarIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: SaveManager.profileName ?? '',
    );
    _avatarIndex = SaveManager.avatarIndex;
    GoldManager.initialize();
    LifeManager.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 30) return;

    await SaveManager.saveProfile(name: name);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Player name saved.')),
    );
    setState(() {});
  }

  Future<void> _selectAvatar(int index) async {
    await SaveManager.saveAvatarIndex(index);
    if (!mounted) return;
    setState(() => _avatarIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providers =
        user?.providerData.map((p) => p.providerId).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Player Info')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: _AvatarCircle(
              index: _avatarIndex,
              size: 104,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Choose your avatar',
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
            decoration: const InputDecoration(
              labelText: 'Player Name',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveName,
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 32),
          _ResourceCard(
            title: 'Gold',
            icon: Icons.monetization_on_outlined,
            value: '${GoldManager.balance}',
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            title: 'Lives',
            icon: Icons.favorite_outline,
            value: LifeManager.isGoldenMember
                ? '∞'
                : '${LifeManager.lifeCount}',
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            title: 'Membership',
            icon: Icons.workspace_premium_outlined,
            value: _membershipLabel(LifeManager.membership),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tool Inventory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ..._toolInventory(),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'Not connected'),
          ),
          ListTile(
            leading: const Icon(Icons.login_outlined),
            title: const Text('Sign-in Method'),
            subtitle: Text(
              providers?.isNotEmpty == true
                  ? providers!
                  : 'Testing / guest',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _toolInventory() {
    const tools = [
      (
        GameToolType.timeRewind,
        'UNDO',
        Icons.undo,
      ),
      (
        GameToolType.revive,
        'REMOVE',
        Icons.remove_circle_outline,
      ),
      (
        GameToolType.positionSwap,
        'SWAP',
        Icons.swap_horiz,
      ),
      (
        GameToolType.duplicate,
        'DUPLICATE',
        Icons.copy_outlined,
      ),
    ];

    return [
      for (final item in tools)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ResourceCard(
            title: item.$2,
            icon: item.$3,
            value: '${ToolManager.savedUsesFor(item.$1)} uses',
          ),
        ),
    ];
  }

  String _membershipLabel(String membership) {
    return switch (membership) {
      'golden' => 'Gold Member',
      'premium' => 'Premium Member',
      _ => 'General Member',
    };
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
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final selected = index == selectedIndex;

        return GestureDetector(
          onTap: () => onSelected(index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _AvatarCircle(
                index: index,
                size: double.infinity,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.index,
    required this.size,
  });

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, 11);
    final column = safeIndex % 4;
    final row = safeIndex ~/ 4;

    final alignment = Alignment(
      -1 + (column * 2 / 3),
      -1 + (row * 2 / 2),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          minWidth: 256,
          maxWidth: 256,
          minHeight: 256,
          maxHeight: 256,
          alignment: alignment,
          child: Image.asset(
            'assets/avatars/avatar_sheet.png',
            width: 256,
            height: 256,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
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
      appBar: AppBar(title: const Text('Evolution Progress')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chapters.length,
        itemBuilder: (_, index) {
          final chapter = chapters[index];
          final isCurrent = chapter.$1.toLowerCase() == currentChapterName;
          final isCompleted =
              index < _chapterIndex(currentChapterName);

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
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(chapter.$1),
              subtitle: Text(
                '${chapter.$2} stages · $status',
              ),
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
    const names = [
      'ocean',
      'land',
      'sky',
      'history',
      'tech',
      'universe',
    ];

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
    'chapter1Ocean',
    'chapter2Land',
    'chapter3Sky',
    'chapter4History',
    'chapter5Tech',
    'chapter6Universe',
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
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
      return;
    }

    final result = <String, Set<int>>{};

    for (final chapterKey in _chapterKeys) {
      result[chapterKey] =
          await CreatureCollectionService.loadDiscovered(chapterKey);
    }

    if (!mounted) return;

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
      appBar: AppBar(
        title: const Text('Creature Collection'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final creature = creatures[index];

                          return _CreatureCollectionCard(
                            creature: creature,
                            discovered: discovered.contains(creature.value),
                          );
                        },
                        childCount: creatures.length,
                      ),
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
            Text(
              chapterName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$discovered / $total discovered'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Undiscovered',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
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
                      const Icon(
                        Icons.monetization_on,
                        size: 56,
                      ),
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
            title: const Text('Background Music'),
            value: _audio.musicEnabled,
            onChanged: (value) async {
              await _audio.setMusicEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: const Text('Music Volume'),
            subtitle: Slider(
              value: _audio.musicVolume,
              onChanged: (value) async {
                await _audio.setMusicVolume(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Sound Effects'),
            value: _audio.sfxEnabled,
            onChanged: (value) async {
              await _audio.setSfxEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: const Text('Sound Effects Volume'),
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
          const ListTile(
            title: Text('Language'),
            subtitle: Text('Use the app language setting.'),
          ),
          const ListTile(
            title: Text('Game Data'),
            subtitle: Text(
              'Save and account data management will be connected later.',
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
      appBar: AppBar(title: const Text('Game Guide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'How to Play',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Use the 4×4 board to move and merge identical life forms into the next evolution stage.',
          ),
          SizedBox(height: 24),
          Text(
            'Six Chapters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ocean → Land → Sky → History → Technology → Space',
          ),
          SizedBox(height: 24),
          Text(
            'Resources',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
      appBar: AppBar(title: const Text('Version Info')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          ListTile(
            title: Text('App'),
            subtitle: Text('Rebirth 2048'),
          ),
          ListTile(
            title: Text('Game Version'),
            subtitle: Text('Current development build'),
          ),
          ListTile(
            title: Text('Build'),
            subtitle: Text(
              'Read from the platform package in the release build.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
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







