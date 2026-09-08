import 'package:shared_preferences/shared_preferences.dart';

/// Persistent in-game gold wallet.
class GoldManager {
  GoldManager._();

  static const String _balanceKey = 'rebirth_2048_gold_balance_v1';
  static const String _spentKey = 'rebirth_2048_gold_spent_v1';

  static SharedPreferences? _preferences;

  static Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  static int get balance => _preferences?.getInt(_balanceKey) ?? 0;
  static int get lifetimeSpent => _preferences?.getInt(_spentKey) ?? 0;

  static Future<bool> spend(int amount) async {
    if (amount <= 0 || balance < amount) return false;
    await initialize();
    final newBalance = balance - amount;
    final newSpent = lifetimeSpent + amount;
    await _preferences!.setInt(_balanceKey, newBalance);
    await _preferences!.setInt(_spentKey, newSpent);
    return true;
  }

  static Future<void> add(int amount) async {
    if (amount <= 0) return;
    await initialize();
    await _preferences!.setInt(_balanceKey, balance + amount);
  }

  static Future<void> reset() async {
    await initialize();
    await _preferences!.remove(_balanceKey);
    await _preferences!.remove(_spentKey);
  }
}
