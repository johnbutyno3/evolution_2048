import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminTestPage extends StatefulWidget {
  const AdminTestPage({super.key});
  @override
  State<AdminTestPage> createState() => _AdminTestPageState();
}

class _AdminTestPageState extends State<AdminTestPage> {
  final _gold = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  bool _loading = true;
  bool _busy = false;
  String _mode = 'general';
  String? _expiresAt;
  String _message = '';
  int? _lives;
  bool? _infiniteLives;
  String? _lifeMode;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gold.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) return;
    try {
      final r = await _functions.httpsCallable('adminGetTestAccountState').call({'uid': _uid});
      final d = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        _mode = d['membershipMode'] as String? ?? 'general';
        _expiresAt = d['expiresAt'] as String?;
        _gold.text = ((d['goldBalance'] as num?)?.toInt() ?? 0).toString();
        _loading = false;
      });
      final lifeResult = await _functions.httpsCallable('getLifeState').call();
      final life = Map<String, dynamic>.from(lifeResult.data as Map);
      if (!mounted) return;
      setState(() {
        _lives = (life['lives'] as num?)?.toInt();
        _infiniteLives = life['infiniteLives'] == true;
        _lifeMode = life['lifeMode'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _message = e.toString(); });
    }
  }

  Future<void> _membership(String mode) async {
    if (_uid.isEmpty) return;
    setState(() { _busy = true; _message = ''; });
    try {
      final r = await _functions.httpsCallable('adminSetMembershipMode').call({
        'uid': _uid, 'mode': mode, 'durationDays': 30,
      });
      final d = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _expiresAt = d['expiresAt'] as String?;
        _message = 'Membership switched to $mode.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _load();
  }

  Future<void> _setGold() async {
    final value = int.tryParse(_gold.text.trim());
    if (_uid.isEmpty || value == null || value < 0) {
      setState(() => _message = 'Enter a valid non-negative Gold amount.');
      return;
    }
    setState(() { _busy = true; _message = ''; });
    try {
      await _functions.httpsCallable('adminSetGoldBalance').call({
        'uid': _uid, 'balance': value,
      });
      if (mounted) setState(() => _message = 'Gold balance set to $value.');
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(String mode) {
    switch (mode) {
      case 'premium': return 'Premium';
      case 'golden': return 'Golden';
      default: return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Controls')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Test Controls')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin Test Account'),
            subtitle: Text(_auth.currentUser?.email ?? 'Signed out'),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Membership', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Current: ${_label(_mode)}'),
              if (_expiresAt != null) Text('Expires: $_expiresAt'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                _button('general', 'General'),
                _button('premium', 'Premium'),
                _button('golden', 'Golden'),
              ]),
            ]),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Life', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Lives: ${_infiniteLives == true ? '∞' : (_lives?.toString() ?? '--')}'),
              Text('Infinite Lives: ${_infiniteLives ?? false}'),
              Text('Life Mode: ${_lifeMode ?? '--'}'),
            ]),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gold Balance', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _gold,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Gold balance', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _setGold,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Set Gold'),
              ),
            ]),
          )),
          if (_message.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_message),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh State'),
          ),
        ],
      ),
    );
  }

  Widget _button(String mode, String label) => OutlinedButton(
    onPressed: _busy ? null : () => _membership(mode),
    child: Text(label),
  );
}
