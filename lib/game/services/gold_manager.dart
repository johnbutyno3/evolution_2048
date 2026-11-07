import '../../services/supabase_account_service.dart';

/// Client facade for the server-authoritative Gold wallet.
class GoldManager {
  GoldManager._();

  static int? _cachedBalance;
  static int? _cachedLifetimeSpent;

  static Future<void> initialize() async {
    await refresh();
  }

  /// UI cache only. The server remains the source of truth.
  static int get balance => _cachedBalance ?? 0;
  static int get lifetimeSpent => _cachedLifetimeSpent ?? 0;

  /// Clears account-scoped Gold cache when the authenticated account changes.
  static void clearCachedState() {
    _cachedBalance = null;
    _cachedLifetimeSpent = null;
  }

  /// Applies the validated Supabase account balance without inventing
  /// lifetime-spend data that the account snapshot does not provide.
  static void applySupabaseBalance(int balance) {
    if (balance < 0) throw ArgumentError.value(balance, 'balance');
    _cachedBalance = balance;
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
    try {
      // Use the same timezone-aware, fully validated snapshot path as account
      // bootstrap. Calling account-snapshot with an empty body is rejected by
      // the Edge Function (timezone is mandatory), which previously left shop
      // screens showing a stale Gold cache without surfacing the failure.
      final snapshot = await SupabaseAccountService.fetchSnapshot();
      applySupabaseBalance(snapshot.gold);
      return _cachedBalance;
    } on SupabaseAccountException {
      // Keep the last validated balance; a failed read never grants or spends.
      return null;
    }
  }

}
