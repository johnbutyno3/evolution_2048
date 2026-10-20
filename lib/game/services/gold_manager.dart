import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pending_operation_store.dart';

/// Client facade for the server-authoritative Gold wallet.
class GoldManager {
  GoldManager._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static int? _cachedBalance;
  static int? _cachedLifetimeSpent;
  static int _cacheGeneration = 0;
  static Future<void> initialize() async {
    await refresh();
  }

  /// UI cache only. The server remains the source of truth.
  static int get balance => _cachedBalance ?? 0;
  static int get lifetimeSpent => _cachedLifetimeSpent ?? 0;

  /// Clears account-scoped Gold cache when Firebase authentication changes.
  static void clearCachedState() {
    _cacheGeneration++;
    _cachedBalance = null;
    _cachedLifetimeSpent = null;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    final generation = _cacheGeneration;
    try {
      final callable = _functions.httpsCallable('getGoldBalance');
      final result = await callable.call();
      if (_cacheGeneration != generation ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return null;
      }
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
      if (_cacheGeneration == generation &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        _cachedBalance = null;
        _cachedLifetimeSpent = null;
      }
    }

    return null;
  }

  static Future<bool> spend(int amount) async {
    if (amount <= 0) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    final generation = _cacheGeneration;
    try {
      return await PendingOperationStore.runExclusive(
        'gold_spend',
        '$amount',
        () async {
          if (_cacheGeneration != generation ||
              FirebaseAuth.instance.currentUser?.uid != uid) {
            return false;
          }
          try {
            final operationId = await PendingOperationStore.getOrCreate('gold_spend', '$amount');
            final result = await _functions.httpsCallable('spendGold').call({
              'amount': amount,
              'operationId': operationId,
            });
            if (_cacheGeneration != generation ||
                FirebaseAuth.instance.currentUser?.uid != uid) {
            return false;
          }
            final data = result.data;
            final value = data is Map ? data['balance'] : null;
            if (value is! num || value.toInt() < 0) return false;
            _cachedBalance = value.toInt();
            final spent = data is Map ? data['lifetimeSpent'] : null;
            _cachedLifetimeSpent = spent is num && spent.toInt() >= 0
                ? spent.toInt()
                : lifetimeSpent + amount;
            await PendingOperationStore.complete('gold_spend', '$amount', expectedUid: uid);
            return true;
          } on FirebaseFunctionsException {
            // The server may have committed before the response failed.
            // Preserve the ID so a retry replays the original receipt.
            return false;
          }
        },
      );
    } on StateError {
      return false;
    }
  }
}

