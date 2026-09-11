import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../game/services/audio_manager.dart';
import '../game/services/save_manager.dart';
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
            subtitle: 'Chapters and progress',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EvolutionProgressPage()),
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
            title: 'Coins',
            subtitle: 'Balance and spending history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoinsPage()),
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: SaveManager.profileName ?? '');
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Player Info')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 42)),
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
            child: FilledButton(onPressed: _saveName, child: const Text('Save')),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Membership'),
            subtitle: const Text('General Member'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'Not connected'),
          ),
          ListTile(
            leading: const Icon(Icons.login_outlined),
            title: const Text('Sign-in Method'),
            subtitle: Text(providers?.isNotEmpty == true ? providers! : 'Testing / guest'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Avatar selection will use discovered creatures. Unlocked creature data will be connected here next.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class EvolutionProgressPage extends StatelessWidget {
  const EvolutionProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    const chapters = ['Ocean', 'Land', 'Sky', 'History', 'Technology', 'Universe'];
    return Scaffold(
      appBar: AppBar(title: const Text('Evolution Progress')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chapters.length,
        itemBuilder: (_, index) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(chapters[index]),
            subtitle: const Text('Progress data will be connected to server progress.'),
          ),
        ),
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creature Collection')),
      body: const Center(
        child: Text('Discovered creatures will appear here by chapter.'),
      ),
    );
  }
}

class CoinsPage extends StatelessWidget {
  const CoinsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coins')),
      body: const Center(
        child: Text('Coin balance and spending history will appear here.'),
      ),
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
            subtitle: Text('Save and account data management will be connected later.'),
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
          Text('How to Play', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('Use the 4×4 board to move and merge identical life forms into the next evolution stage.'),
          SizedBox(height: 24),
          Text('Six Chapters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Ocean → Land → Sky → History → Technology → Universe'),
          SizedBox(height: 24),
          Text('More Rules', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Life, tools, scoring, membership and shop rules are defined by the project specification.'),
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
      body: const ListView(
        padding: EdgeInsets.all(20),
        children: [
          ListTile(title: Text('App'), subtitle: Text('Rebirth 2048')),
          ListTile(title: Text('Game Version'), subtitle: Text('Current development build')),
          ListTile(title: Text('Build'), subtitle: Text('Read from the platform package in the release build.')),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
