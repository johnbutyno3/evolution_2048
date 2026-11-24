import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/supabase_backend.dart';
import '../l10n/app_localizations.dart';
import 'admin_test_page.dart';

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
    final allowed = await AdminService.checkAdmin();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_allowed) {
      return const Scaffold(
        body: Center(child: Text(AppLocalizations.of(context)!.adminRequired)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.adminTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.storefront_outlined,
            title: AppLocalizations.of(context)!.adminShopParameters,
            subtitle: AppLocalizations.of(context)!.adminShopSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminShopParametersPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.help_outline,
            title: AppLocalizations.of(context)!.adminQAManagement,
            subtitle: AppLocalizations.of(context)!.adminQASubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminQAPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.inbox_outlined,
            title: AppLocalizations.of(context)!.adminPlayerMessages,
            subtitle: AppLocalizations.of(context)!.adminMessagesSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminMessagesPage()),
            ),
          ),
          _AdminCard(
            icon: Icons.search,
            title: AppLocalizations.of(context)!.adminPlayerSearch,
            subtitle: AppLocalizations.of(context)!.adminPlayerSearchSubtitle,
            onTap: () => _showComingSoon(AppLocalizations.of(context)!.adminPlayerSearch),
          ),
          _AdminCard(
            icon: Icons.tune,
            title: AppLocalizations.of(context)!.adminGameParameters,
            subtitle: AppLocalizations.of(context)!.adminGameParametersSubtitle,
            onTap: () => _showComingSoon(AppLocalizations.of(context)!.adminGameParameters),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.adminComingSoon(name))),
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
    try {
      await AdminService.saveShopParameters(_values);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.shopParametersSaved)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.shopParametersSaveFailed(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label, {bool decimal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: '${_values[key] ?? ''}',
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (decimal) {
            _values[key] = value;
          } else {
            _values[key] = int.tryParse(value) ?? value;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppLocalizations.of(context)!.adminShopParameters)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppLocalizations.of(context)!.goldPackagesUsd, style: _headingStyle),
          const SizedBox(height: 12),
          _field('gold300UsdPrice', '300 Gold USD', decimal: true),
          _field('gold1000UsdPrice', '1,000 Gold USD', decimal: true),
          _field('gold4000UsdPrice', '4,000 Gold USD', decimal: true),
          _field('gold10000UsdPrice', '10,000 Gold USD', decimal: true),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.permanentMembershipUsd, style: _headingStyle),
          const SizedBox(height: 12),
          _field('premiumUsdPrice', 'Premium Member USD', decimal: true),
          _field('goldenUsdPrice', 'Golden Member USD', decimal: true),
          _field('goldenUpgradeUsdPrice', 'Premium → Golden Upgrade USD', decimal: true),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.evolutionToolsGold, style: _headingStyle),
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
            _field('${tool.$1}20Price', '20 uses Gold price'),
            _field('${tool.$1}50Price', '50 uses Gold price'),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveParameters),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.adminQAManagement)),
      body: Center(child: Text(AppLocalizations.of(context)!.qaMigrationPending)),
    );
  }
}

class AdminMessagesPage extends StatelessWidget {
  const AdminMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppLocalizations.of(context)!.adminPlayerMessages)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.unableLoadMessages(snapshot.error ?? '')));
          }
          final messages = snapshot.data ?? const <Map<String, dynamic>>[];
          if (messages.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noPlayerMessages));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final data = messages[index];
              final ticket = data['ticket'];
              final ticketData = ticket is Map ? ticket : const <String, dynamic>{};
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text('${ticketData['subject'] ?? AppLocalizations.of(context)!.playerMessage} · ${ticketData['status'] ?? 'open'}'),
                  subtitle: Text('${data['body'] ?? ''}\nUID: ${ticketData['user_id'] ?? ''}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMessages() async {
    final rows = await SupabaseBackend.client
        .from('support_messages')
        .select('id, body, created_at, ticket:support_tickets!inner(user_id, subject, status)')
        .eq('sender_role', 'player')
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
