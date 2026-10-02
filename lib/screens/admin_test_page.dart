import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';

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
  bool _allToolsEnabledForTest = false;
  bool? _authDisabled;
  String? _enforcementStatus;
  String? _enforcementReason;
  String? _lockedAt;
  String? _restrictedUntil;
  String? _riskLevel;
  int? _riskScore;
  List<Map<String, dynamic>> _securityEvents = [];

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
        _allToolsEnabledForTest = d['allToolsEnabledForTest'] == true;
        _loading = false;
      });
      final securityResult = await _functions.httpsCallable('adminGetSecurityState').call({'uid': _uid});
      final security = Map<String, dynamic>.from(securityResult.data as Map);
      if (!mounted) return;
      setState(() {
        _authDisabled = security['authDisabled'] == true;
        _enforcementStatus = security['enforcementStatus'] as String?;
        _enforcementReason = security['enforcementReason'] as String?;
        _lockedAt = security['lockedAt'] as String?;
        _restrictedUntil = security['restrictedUntil'] as String?;
        _riskLevel = security['riskLevel'] as String?;
        _riskScore = (security['riskScore'] as num?)?.toInt();
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
      // Keep the already-mounted Home page cache in sync immediately.
      final lifeResult = await _functions.httpsCallable('getLifeState').call();
      LifeManager.applyServerState(
        Map<String, dynamic>.from(lifeResult.data as Map),
      );
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
      final goldResult = await _functions.httpsCallable('getGoldBalance').call();
      GoldManager.applyServerState(
        Map<String, dynamic>.from(goldResult.data as Map),
      );
      if (mounted) setState(() => _message = 'Gold balance set to $value.');
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _setUnlockedChapter(int chapterIndex) async {
    if (_uid.isEmpty) return;
    setState(() { _busy = true; _message = ''; });
    try {
      final r = await _functions.httpsCallable('adminSetUnlockedChapter').call({
        'uid': _uid,
        'chapterIndex': chapterIndex,
      });
      final d = Map<String, dynamic>.from(r.data as Map);
      if (mounted) {
        setState(() => _message =
            'Test mode: chapters unlocked through C' +
            (((d['unlockedChapterIndex'] as num).toInt()) + 1).toString() + '.');
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAllToolsEnabled(bool enabled) async {
    if (_uid.isEmpty) return;
    setState(() { _busy = true; _message = ''; });
    try {
      final r = await _functions.httpsCallable('adminSetAllToolsEnabled').call({
        'uid': _uid,
        'enabled': enabled,
      });
      final d = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        _allToolsEnabledForTest = d['allToolsEnabledForTest'] == true;
        _message = enabled
            ? 'Test mode: all tools are enabled in every chapter.'
            : 'Test mode: chapter tool restrictions restored.';
      });
      // Refresh inventory immediately so the next game sees the test flag.
      await ToolManager.refreshInventory();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }



  Future<void> _loadSecurityEvents() async {
    if (_uid.isEmpty) return;
    setState(() { _busy = true; _message = ''; });
    try {
      final result = await _functions.httpsCallable('adminGetSecurityEvents').call({'uid': _uid});
      final data = Map<String, dynamic>.from(result.data as Map);
      final events = (data['events'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _securityEvents = events;
        _message = events.isEmpty
            ? 'No security events found for this account.'
            : 'Loaded ${events.length} latest security events.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _resetSecurityState() async {
    if (_uid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Security State?'),
        content: const Text(
          'This clears the test account security lock and risk score. '
          'It does not change Firebase Auth disabled status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _busy = true; _message = ''; });
    try {
      await _functions.httpsCallable('adminResetSecurityState').call({
        'uid': _uid,
        'confirm': true,
      });
      if (!mounted) return;
      setState(() {
        _enforcementStatus = 'active';
        _enforcementReason = null;
        _riskLevel = 'NORMAL';
        _riskScore = 0;
        _restrictedUntil = null;
        _message = 'Security Enforcement reset for this test account.';
      });
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
              const SizedBox(height: 4),
              const Text('Test membership is stored on the server until changed.', style: TextStyle(fontSize: 12)),
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
              const Text('Security Enforcement', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('UID: $_uid'),
              Text('Firebase Auth Disabled: ${_authDisabled ?? '--'}'),
              Text('Enforcement Status: ${_enforcementStatus ?? '--'}'),
              Text('Risk Level: ${_riskLevel ?? '--'}'),
              Text('Risk Score: ${_riskScore ?? 0}'),
              if (_enforcementReason != null) Text('Reason: $_enforcementReason'),
              if (_lockedAt != null) Text('Locked At: $_lockedAt'),
              if (_restrictedUntil != null) Text('Restricted Until: $_restrictedUntil'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _resetSecurityState,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Reset Security Enforcement'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _loadSecurityEvents,
                icon: const Icon(Icons.manage_search),
                label: const Text('Load Latest Security Events'),
              ),
              if (_securityEvents.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final event in _securityEvents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${event['timestamp'] ?? '--'} · ${event['eventType']}'),
                    subtitle: Text(
                      'Reason: ${event['reason']} | Severity: ${event['severity']} | '
                      'Risk: ${event['riskScore']} (${event['riskLevel']}) | Status: ${event['status']}'
                      '${event['toolType'] == null ? '' : ' | Tool: ${event['toolType']}'}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ]),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gold Balance', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Gold is independent from membership.', style: TextStyle(fontSize: 12)),
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

          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Chapter Test / Cheat', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Admin-only test control. Unlocks chapters for testing.'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var index = 0; index < 6; index++)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _setUnlockedChapter(index),
                    child: Text('Unlock C' + (index + 1).toString()),
                  ),
              ]),
            ]),
          )),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tool Test Mode', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _allToolsEnabledForTest
                    ? 'All four tools are unlocked in every chapter.'
                    : 'Normal chapter tool restrictions are active.',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable all tools in every chapter'),
                value: _allToolsEnabledForTest,
                onChanged: _busy ? null : _setAllToolsEnabled,
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
