import 'package:cloud_functions/cloud_functions.dart';

/// Client facade for the server-authoritative Gold wallet.
class GoldManager {
  GoldManager._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static int? _cachedBalance;
  static int? _cachedLifetimeSpent;

  static Future<void> initialize() async {
    await refresh();
  }

  /// UI cache only. The server remains the source of truth.
  static int get balance => _cachedBalance ?? 0;
  static int get lifetimeSpent => _cachedLifetimeSpent ?? 0;

  static Future<int?> refresh() async {
    try {
      final callable = _functions.httpsCallable('getGoldBalance');
      final result = await callable.call();
      final data = result.data;
      final value = data is Map ? data['balance'] : null;
      if (value is num && value.toInt() >= 0) {
        _cachedBalance = value.toInt();
        final spent = data is Map ? data['lifetimeSpent'] : null;
        _cachedLifetimeSpent = spent is num && spent.toInt() >= 0
            ? spent.toInt()
            : 0;
        return _cachedBalance;
      }
    } on FirebaseFunctionsException {
      _cachedBalance = null;
    }

    return null;
  }

  static Future<bool> spend(int amount) async {
    if (amount <= 0) return false;

    try {
      final callable = _functions.httpsCallable('spendGold');
      final result = await callable.call(<String, dynamic>{'amount': amount});
      final data = result.data;
      final value = data is Map ? data['balance'] : null;
      if (value is num && value.toInt() >= 0) {
        _cachedBalance = value.toInt();
        final spent = data is Map ? data['lifetimeSpent'] : null;
        _cachedLifetimeSpent = spent is num && spent.toInt() >= 0
            ? spent.toInt()
            : lifetimeSpent + amount;
        return true;
      }
    } on FirebaseFunctionsException {
      return false;
    }

    return false;
  }
}
