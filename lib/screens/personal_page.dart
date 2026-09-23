import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
import 'admin_test_page.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline),
              ),
              title: Text(AppLocalizations.of(context)!.playerBasicInfo),
              subtitle: Text(AppLocalizations.of(context)!.playerBasicInfoSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerInfoPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            icon: Icons.menu_book_outlined,
            title: AppLocalizations.of(context)!.creatureCollection,
            subtitle: AppLocalizations.of(context)!.creatureCollectionSubtitle,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CollectionPage())),
          ),
          _SectionCard(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context)!.settings,
            subtitle: AppLocalizations.of(context)!.settingsSubtitle,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          _SectionCard(
            icon: Icons.help_outline,
            title: AppLocalizations.of(context)!.gameGuide,
            subtitle: AppLocalizations.of(context)!.gameGuideSubtitle,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GameGuidePage())),
          ),
          _SectionCard(
            icon: Icons.info_outline,
            title: AppLocalizations.of(context)!.versionInfo,
            subtitle: AppLocalizations.of(context)!.versionInfoSubtitle,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const VersionInfoPage())),
          ),
          _SectionCard(
            icon: Icons.feedback_outlined,
            title: AppLocalizations.of(context)!.messagesFeedback,
            subtitle: AppLocalizations.of(context)!.messagesFeedbackSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackPage()),
            ),
          ),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: user == null
                ? null
                : FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.data?.data()?['isAdmin'] != true) {
                return const SizedBox.shrink();
              }
              return _SectionCard(
                icon: Icons.admin_panel_settings_outlined,
                title: AppLocalizations.of(context)!.testControls,
                subtitle: AppLocalizations.of(context)!.testControlsSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminTestPage()),
                ),
              );
            },
          ),
          _SectionCard(
            icon: Icons.info_outline,
            title: AppLocalizations.of(context)!.aboutGame,
            subtitle: AppLocalizations.of(context)!.aboutGameSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutGamePage()),
            ),
          ),
          const SizedBox(height: 12),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLocalizations.of(context)!.logOut),
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
          title: Text(AppLocalizations.of(context)!.logOut),
          content: Text(
            AppLocalizations.of(context)!.logoutConfirm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppLocalizations.of(context)!.logOut),
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
        const SnackBar(content: Text(AppLocalizations.of(context)!.playerNameEmpty)),
      );
      return;
    }

    try {
      final success = await PlayerProfileService.updatePlayerName(name);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? AppLocalizations.of(context)!.playerNameUpdated : AppLocalizations.of(context)!.playerNameUpdateFailed,
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
        SnackBar(content: Text('${AppLocalizations.of(context)!.playerNameUpdateError} $error')),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.playerInfo)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _AvatarCircle(index: _avatarIndex, size: 104)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              AppLocalizations.of(context)!.chooseAvatar,
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
              labelText: AppLocalizations.of(context)!.profileNameLabel,
              border: OutlineInputBorder(),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveName,
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(AppLocalizations.of(context)!.playerId),
              subtitle: Text(
                _loading
                    ? AppLocalizations.of(context)!.loading
                    : (_playerId.isEmpty ? AppLocalizations.of(context)!.notAvailable : _playerId),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(AppLocalizations.of(context)!.membership),
              subtitle: Text(
                membership == 'golden'
                    ? AppLocalizations.of(context)!.goldenMember
                    : membership == 'premium'
                    ? AppLocalizations.of(context)!.premiumMember
                    : AppLocalizations.of(context)!.generalMember,
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

  String _chapterName(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    const prefix = 'Chapter';
    final names = [
      l10n.chapterOcean,
      l10n.chapterLand,
      l10n.chapterSky,
      l10n.chapterHistory,
      l10n.chapterTechnology,
      l10n.chapterSpace,
    ];
    return '$prefix ${index + 1} · ${names[index]}';
  }

  String _chapterShortName(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.chapterOcean,
      l10n.chapterLand,
      l10n.chapterSky,
      l10n.chapterHistory,
      l10n.chapterTechnology,
      l10n.chapterSpace,
    ][index];
  }

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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.creatureCollection)),
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
                        chapterName: _chapterName(context, _selectedChapter),
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
                        itemCount: _chapterKeys.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(_chapterShortName(context, index)),
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
            Text(AppLocalizations.of(context)!.discoveredCount(discovered, total)),
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
                    AppLocalizations.of(context)!.undiscovered,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.stageLabel(creature.stage),
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
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.gold)),
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
                        AppLocalizations.of(context)!.goldBalance,
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
                  title: Text(AppLocalizations.of(context)!.lifetimeSpent),
                  trailing: Text(AppLocalizations.of(context)!.goldAmount(GoldManager.lifetimeSpent)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                AppLocalizations.of(context)!.goldUsage,
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.backgroundMusic),
            value: _audio.musicEnabled,
            onChanged: (value) async {
              await _audio.setMusicEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.musicVolume),
            subtitle: Slider(
              value: _audio.musicVolume,
              onChanged: (value) async {
                await _audio.setMusicVolume(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.soundEffects),
            value: _audio.sfxEnabled,
            onChanged: (value) async {
              await _audio.setSfxEnabled(value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.soundEffectsVolume),
            subtitle: Slider(
              value: _audio.sfxVolume,
              onChanged: (value) async {
                await _audio.setSfxVolume(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SwitchListTile(
            title: Text(AppLocalizations.of(context)!.vibration),
            value: true,
            onChanged: null,
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.language),
            trailing: DropdownButton<String>(
              value: SaveManager.localeCode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text(AppLocalizations.of(context)!.english)),
                DropdownMenuItem(value: 'zh', child: Text(AppLocalizations.of(context)!.traditionalChinese)),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.gameGuide)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppLocalizations.of(context)!.howToPlay,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.howToPlayDescription,
          ),
          SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.sixChapters,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.chapterSequence),
          SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.resources,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.resourcesDescription,
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.versionInfo)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(title: Text(AppLocalizations.of(context)!.app), subtitle: Text(AppLocalizations.of(context)!.gameTitle)),
          ListTile(
            title: Text(AppLocalizations.of(context)!.gameVersion),
            subtitle: Text(AppLocalizations.of(context)!.currentDevelopmentBuild),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.build),
            subtitle: Text(
              AppLocalizations.of(context)!.buildDescription,
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.aboutGame)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(AppLocalizations.of(context)!.gameTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          Text(AppLocalizations.of(context)!.creator, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.creatorName),
          const SizedBox(height: 18),
          Text(AppLocalizations.of(context)!.musicSources, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.musicSourcesDescription),
          const SizedBox(height: 18),
          Text(AppLocalizations.of(context)!.artworkServices, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.artworkServicesDescription),
          const SizedBox(height: 18),
          Text(AppLocalizations.of(context)!.version, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.developmentBuild),
        ],
      ),
    );
  }
}
