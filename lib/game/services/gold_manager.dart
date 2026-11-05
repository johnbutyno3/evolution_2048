import '../../services/supabase_backend.dart';

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
      final client = SupabaseBackend.client;
      if (client.auth.currentSession == null) return null;
      final response = await client.functions.invoke(
        'account-snapshot',
        method: HttpMethod.post,
        body: <String, dynamic>{},
      );
      if (response.status < 200 || response.status >= 300 ||
          response.data is! Map) {
        return null;
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final balance = data['gold'];
      if (data['userId'] != client.auth.currentUser?.id ||
          balance is! num ||
          !balance.isFinite ||
          balance.toInt() < 0 ||
          balance != balance.toInt()) {
        return null;
      }
      applySupabaseBalance(balance.toInt());
      return _cachedBalance;
    } catch (_) {
      return null;
    }
  }

}
