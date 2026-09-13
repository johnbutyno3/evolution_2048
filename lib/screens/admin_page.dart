import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final allowed = await AdminService.isAdmin();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_allowed) {
      return Scaffold(
        body: Center(child: Text('Administrator access required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.storefront_outlined,
            title: 'Shop Parameters',
            subtitle: 'Gold, Lives, Tools and Membership settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdminShopParametersPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.help_outline,
            title: 'Q&A Management',
            subtitle: 'Manage frequently asked questions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminQAPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.inbox_outlined,
            title: 'Player Messages',
            subtitle: 'Read feedback and reply to players',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminMessagesPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.search,
            title: 'Player Search',
            subtitle: 'Player lookup will be connected here',
            onTap: () => _showComingSoon('Player Search'),
          ),
          _AdminCard(
            icon: Icons.tune,
            title: 'Game Parameters',
            subtitle: 'Chapter and gameplay settings',
            onTap: () => _showComingSoon('Game Parameters'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name management will be added next.')),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
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
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class AdminShopParametersPage extends StatefulWidget {
  const AdminShopParametersPage({super.key});

  @override
  State<AdminShopParametersPage> createState() => _AdminShopParametersPageState();
}

class _AdminShopParametersPageState extends State<AdminShopParametersPage> {
  Map<String, dynamic> _values = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await AdminService.loadShopParameters();
    if (!mounted) return;
    setState(() {
      _values = {...AdminService.defaultShopParameters, ...values};
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AdminService.saveShopParameters(_values);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shop parameters saved.')),
    );
  }

  Widget _field(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: '${_values[key] ?? ''}',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          final number = int.tryParse(value);
          _values[key] = number ?? value;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Parameters')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Gold Packages', style: _headingStyle),
          const SizedBox(height: 12),
          _field('gold100Price', '100 Gold price'),
          _field('gold550Price', '550 Gold price'),
          _field('gold1200Price', '1,200 Gold price'),
          _field('gold2500Price', '2,500 Gold price'),
          const SizedBox(height: 12),
          const Text('Lives', style: _headingStyle),
          const SizedBox(height: 12),
          _field('life1Price', '+1 Life Gold price'),
          _field('life5Price', '+5 Lives Gold price'),
          _field('life10Price', '+10 Lives Gold price'),
          _field('life25Price', '+25 Lives Gold price'),
          const SizedBox(height: 12),
          const Text('Evolution Tools', style: _headingStyle),
          const SizedBox(height: 12),
          for (final tool in const [
            ('undo', 'UNDO'),
            ('remove', 'REMOVE'),
            ('swap', 'SWAP'),
            ('duplicate', 'DUPLICATE'),
          ]) ...[
            Text(tool.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _field('${tool.$1}1Price', '1 use Gold price'),
            _field('${tool.$1}5Price', '5 uses Gold price'),
            _field('${tool.$1}10Price', '10 uses Gold price'),
            _field('${tool.$1}25Price', '25 uses Gold price'),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Parameters'),
          ),
        ],
      ),
    );
  }

  static const _headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}

class AdminQAPage extends StatelessWidget {
  const AdminQAPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Q&A Management')),
      body: Center(
        child: Text('Q&A editing will be connected to Firestore next.'),
      ),
    );
  }
}

class AdminMessagesPage extends StatelessWidget {
  const AdminMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player Messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load messages: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No player messages yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text('${data['type'] ?? 'Other'} · ${data['status'] ?? 'new'}'),
                  subtitle: Text('${data['message'] ?? ''}\nUID: ${data['uid'] ?? ''}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
