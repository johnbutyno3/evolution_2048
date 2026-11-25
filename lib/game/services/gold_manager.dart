import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first Gold wallet and reward ledger.
/// One serialized record keeps balance, idempotency keys, score milestones,
/// and tool inventory together so a reward or purchase cannot be credited twice.
class GoldManager {
  GoldManager._();

  static const String _walletKey = 'rebirth_2048_local_economy_v1';
  static SharedPreferences? _preferences;
  static bool _initialized = false;
  static Map<String, dynamic> _state = <String, dynamic>{
    'balance': 0,
    'lifetimeSpent': 0,
    'cumulativeScore': 0,
    'transactions': <String>[],
    'claimedRewards': <String>[],
    'settledGames': <String>[],
    'toolInventory': <String, int>{},
  };

  static Future<void> initialize() => initializeLocal();

  static Future<void> initializeLocal() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_walletKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final balance = decoded['balance'];
          final spent = decoded['lifetimeSpent'];
          final score = decoded['cumulativeScore'];
          final inventory = decoded['toolInventory'];
          _state = <String, dynamic>{
            'balance': balance is num && balance >= 0 ? balance.toInt() : 0,
            'lifetimeSpent': spent is num && spent >= 0 ? spent.toInt() : 0,
            'cumulativeScore': score is num && score >= 0 ? score.toInt() : 0,
            'transactions': _stringSet(decoded['transactions']),
            'claimedRewards': _stringSet(decoded['claimedRewards']),
            'settledGames': _stringSet(decoded['settledGames']),
            'toolInventory': <String, int>{
              if (inventory is Map)
                for (final entry in inventory.entries)
                  if (entry.value is num && (entry.value as num) >= 0)
                    entry.key.toString(): (entry.value as num).toInt(),
            },
          };
        }
      } catch (_) {
        // A malformed wallet must not grant currency or inventory.
        _state = <String, dynamic>{
          'balance': 0,
          'lifetimeSpent': 0,
          'cumulativeScore': 0,
          'transactions': <String>[],
          'claimedRewards': <String>[],
          'settledGames': <String>[],
          'toolInventory': <String, int>{},
        };
      }
    }
    _initialized = true;
  }

  static List<String> _stringSet(dynamic value) =>
      value is List ? value.whereType<String>().toSet().toList() : <String>[];

  static Future<void> _ensureInitialized() async {
    if (!_initialized) await initializeLocal();
  }

  static int get balance => (_state['balance'] as int?) ?? 0;
  static int get lifetimeSpent => (_state['lifetimeSpent'] as int?) ?? 0;
  static int get cumulativeScore => (_state['cumulativeScore'] as int?) ?? 0;

  static Map<String, int> get toolInventory {
    final raw = _state['toolInventory'];
    if (raw is! Map) return <String, int>{};
    return <String, int>{
      for (final entry in raw.entries)
        if (entry.value is int) entry.key.toString(): entry.value as int,
    };
  }

  static int toolUses(String toolCode) => toolInventory[toolCode] ?? 0;

  static Set<String> get claimedRewardIds =>
      _stringSet(_state['claimedRewards']).toSet();

  static Set<String> get settledGameIds =>
      _stringSet(_state['settledGames']).toSet();

  static Future<void> _persist(Map<String, dynamic> next) async {
    await _ensureInitialized();
    final saved = await _preferences!.setString(_walletKey, jsonEncode(next));
    if (!saved) throw StateError('Could not persist the local Gold wallet.');
    _state = next;
  }

  static Map<String, dynamic> _copyState() => <String, dynamic>{
    'balance': balance,
    'lifetimeSpent': lifetimeSpent,
    'cumulativeScore': cumulativeScore,
    'transactions': _stringSet(_state['transactions']),
    'claimedRewards': _stringSet(_state['claimedRewards']),
    'settledGames': _stringSet(_state['settledGames']),
    'toolInventory': toolInventory,
  };

  /// Adds a one-time reward. The reward ID and balance are saved together.
  static Future<bool> awardOnce({
    required String rewardId,
    required int amount,
  }) async {
    if (rewardId.trim().isEmpty || amount < 0) {
      throw ArgumentError('Invalid reward.');
    }
    await _ensureInitialized();
    final claimed = _stringSet(_state['claimedRewards']);
    if (claimed.contains(rewardId)) return false;
    final next = _copyState();
    claimed.add(rewardId);
    next['claimedRewards'] = claimed;
    next['balance'] = balance + amount;
    final transactions = _stringSet(_state['transactions']);
    transactions.add('reward:$rewardId');
    next['transactions'] = transactions;
    await _persist(next);
    return true;
  }

  /// Settles a completed or game-over session exactly once.
  /// Effective score is the final non-negative score after tool penalties.
  static Future<int> settleGame({
    required String gameId,
    required int effectiveScore,
    required int newSpeciesCount,
    required int highestValue,
  }) async {
    if (gameId.trim().isEmpty) throw ArgumentError.value(gameId, 'gameId');
    if (effectiveScore < 0 || newSpeciesCount < 0) {
      throw ArgumentError('Invalid game settlement values.');
    }
    await _ensureInitialized();
    final settled = _stringSet(_state['settledGames']);
    if (settled.contains(gameId)) return 0;

    final baseReward = 10 + (effectiveScore ~/ 1000) + newSpeciesCount;
    final next = _copyState();
    settled.add(gameId);
    next['settledGames'] = settled;
    next['balance'] = balance + baseReward;
    next['cumulativeScore'] = cumulativeScore + effectiveScore;
    final transactions = _stringSet(_state['transactions']);
    transactions.add('game:$gameId');
    next['transactions'] = transactions;

    final claimed = _stringSet(_state['claimedRewards']);
    final extra = <String, int>{
      'achievement:first-highest-species': highestValue >= 131072 ? 100 : 0,
      'achievement:single-score-10000': effectiveScore >= 10000 ? 50 : 0,
      'achievement:single-score-30000': effectiveScore >= 30000 ? 100 : 0,
      'achievement:single-score-50000': effectiveScore >= 50000 ? 200 : 0,
      'achievement:single-score-100000': effectiveScore >= 100000 ? 500 : 0,
      'score:10000': cumulativeScore + effectiveScore >= 10000 ? 50 : 0,
      'score:50000': cumulativeScore + effectiveScore >= 50000 ? 100 : 0,
      'score:100000': cumulativeScore + effectiveScore >= 100000 ? 200 : 0,
      'score:250000': cumulativeScore + effectiveScore >= 250000 ? 300 : 0,
      'score:500000': cumulativeScore + effectiveScore >= 500000 ? 500 : 0,
      'score:1000000': cumulativeScore + effectiveScore >= 1000000 ? 1000 : 0,
    };
    var extraTotal = 0;
    for (final entry in extra.entries) {
      if (entry.value <= 0 || claimed.contains(entry.key)) continue;
      claimed.add(entry.key);
      extraTotal += entry.value;
      transactions.add('reward:${entry.key}');
    }
    next['claimedRewards'] = claimed;
    next['transactions'] = transactions;
    next['balance'] = (next['balance'] as int) + extraTotal;
    await _persist(next);
    return baseReward + extraTotal;
  }

  static Future<int> awardChapterCompletion(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex > 5) {
      throw ArgumentError.value(chapterIndex, 'chapterIndex');
    }
    const rewards = <int>[200, 300, 400, 500, 600, 800];
    final awarded = await awardOnce(
      rewardId: 'chapter:C${chapterIndex + 1}:first-completion',
      amount: rewards[chapterIndex],
    );
    return awarded ? rewards[chapterIndex] : 0;
  }

  static Future<int> awardAllChaptersCompletion() async {
    const reward = 1000;
    final awarded = await awardOnce(
      rewardId: 'achievement:all-six-chapters',
      amount: reward,
    );
    return awarded ? reward : 0;
  }

  static Future<int> awardCollectionMilestones({
    required int uniqueSpeciesCount,
    required bool allSpeciesCollected,
  }) async {
    const milestones = <int, int>{
      10: 50,
      25: 100,
      50: 200,
      75: 300,
    };
    var awarded = 0;
    for (final entry in milestones.entries) {
      if (uniqueSpeciesCount >= entry.key) {
        if (await awardOnce(
          rewardId: 'collection:${entry.key}',
          amount: entry.value,
        )) {
          awarded += entry.value;
        }
      }
    }
    if (allSpeciesCollected &&
        await awardOnce(rewardId: 'collection:all', amount: 800)) {
      awarded += 800;
    }
    return awarded;
  }

  /// Atomically deducts Gold and grants a tool package in the same wallet record.
  static Future<bool> purchaseTool({
    required String toolCode,
    required int amount,
    required int cost,
    required String transactionId,
  }) async {
    await _ensureInitialized();
    if (toolCode.isEmpty || amount <= 0 || cost < 0 || transactionId.isEmpty) {
      return false;
    }
    final transactions = _stringSet(_state['transactions']);
    if (transactions.contains(transactionId)) return false;
    if (balance < cost) return false;
    final next = _copyState();
    final inventory = Map<String, int>.from(toolInventory);
    inventory[toolCode] = (inventory[toolCode] ?? 0) + amount;
    transactions.add(transactionId);
    next['toolInventory'] = inventory;
    next['transactions'] = transactions;
    next['balance'] = balance - cost;
    next['lifetimeSpent'] = lifetimeSpent + cost;
    await _persist(next);
    return true;
  }

  /// Synchronous gameplay debit; the in-memory state changes immediately and
  /// its single-record persistence is queued before returning to the frame.
  static bool consumeToolLocal(String toolCode) {
    if (!_initialized) return false;
    final inventory = Map<String, int>.from(toolInventory);
    final current = inventory[toolCode] ?? 0;
    if (current <= 0) return false;
    inventory[toolCode] = current - 1;
    final next = _copyState()..['toolInventory'] = inventory;
    _state = next;
    unawaited(_preferences!.setString(_walletKey, jsonEncode(next)));
    return true;
  }

  /// Kept as a compatibility API for old call sites; the single-player app
  /// never fetches Gold from Supabase.
  static void clearCachedState() {}

  @Deprecated('Use local wallet operations; remote account balances are retired.')
  static void applySupabaseBalance(int value) {
    if (value < 0) throw ArgumentError.value(value, 'balance');
    final next = _copyState()..['balance'] = value;
    _state = next;
    if (_initialized) unawaited(_preferences!.setString(_walletKey, jsonEncode(next)));
  }

  @Deprecated('Use local wallet operations; remote account balances are retired.')
  static void applyServerState(Map<String, dynamic> data) {
    final value = data['balance'];
    if (value is num && value >= 0) applySupabaseBalance(value.toInt());
  }

  static Future<int?> refresh() async {
    await _ensureInitialized();
    return balance;
  }
}
