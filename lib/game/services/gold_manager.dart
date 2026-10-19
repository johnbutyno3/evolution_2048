import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';

/// Client facade for the server-authoritative Gold wallet.
class GoldManager {
  GoldManager._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static int? _cachedBalance;
  static int? _cachedLifetimeSpent;
  // Keep an operation ID after an ambiguous failure so a user retry in this
  // process replays the same server transaction instead of spending twice.
  static final Map<int, String> _pendingSpendOperationIds = <int, String>{};

  static String _newOperationId() => List<int>.generate(
        24,
        (_) => math.Random.secure().nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static Future<void> initialize() async {
    await refresh();
  }

  /// UI cache only. The server remains the source of truth.
  static int get balance => _cachedBalance ?? 0;
  static int get lifetimeSpent => _cachedLifetimeSpent ?? 0;

  /// Clears account-scoped Gold cache when Firebase authentication changes.
  static void clearCachedState() {
    _cachedBalance = null;
    _cachedLifetimeSpent = null;
    _pendingSpendOperationIds.clear();
  }

  static void applyServerState(Map<String, dynamic> data) {
    final balance = data['balance'];
    if (balance is num && balance.toInt() >= 0) {
      _cachedBalance = balance.toInt();
    }
    final spent = data['lifetimeSpent'];
    if (spent is num && spent.toInt() >= 0) {
      _cachedLifetimeSpent = spent.toInt();
    }
  }

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

    final operationId = _pendingSpendOperationIds.putIfAbsent(
      amount,
      _newOperationId,
    );

    try {
      final callable = _functions.httpsCallable('spendGold');
      final result = await callable.call(<String, dynamic>{
        'amount': amount,
        'operationId': operationId,
      });
      final data = result.data;
      final value = data is Map ? data['balance'] : null;
      if (value is num && value.toInt() >= 0) {
        _cachedBalance = value.toInt();
        final spent = data is Map ? data['lifetimeSpent'] : null;
        _cachedLifetimeSpent = spent is num && spent.toInt() >= 0
            ? spent.toInt()
            : lifetimeSpent + amount;
        _pendingSpendOperationIds.remove(amount);
        return true;
      }
    } on FirebaseFunctionsException {
      // Keep the ID: the server may have committed before the response failed.
      return false;
    }

    // Keep the ID if the response shape is unexpected as well.
    return false;
  }
}
