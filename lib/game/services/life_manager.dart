import 'package:shared_preferences/shared_preferences.dart';

/// Persistent life system for Evolution 2048.
///
/// Normal members regenerate one life every 40 minutes while below 5.
/// Purchased lives may raise the current count above 5, but automatic
/// regeneration never refills above 5. Golden members have infinite lives.
class LifeManager {
  LifeManager._();

  static const int normalCap = 5;
  static const Duration regenerationInterval = Duration(minutes: 40);

  static const String _lifeKey = 'rebirth_2048_life_count_v1';
  static const String _regenStartKey = 'rebirth_2048_life_regen_start_v1';
  static const String _membershipKey = 'rebirth_2048_membership_v1';

  static SharedPreferences? _preferences;
  static int _lifeCount = normalCap;
  static DateTime? _regenStart;
  static String _membership = 'general';

  static Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    _lifeCount = _preferences!.getInt(_lifeKey) ?? normalCap;
    _membership = _preferences!.getString(_membershipKey) ?? 'general';

    final storedRegenStart = _preferences!.getInt(_regenStartKey);
    _regenStart = storedRegenStart == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(storedRegenStart);

    _applyAutomaticRegeneration();
    await _persist();
  }

  static bool get isGoldenMember => _membership == 'golden';

  static int get lifeCount {
    _applyAutomaticRegeneration();
    return isGoldenMember ? -1 : _lifeCount;
  }

  static String get membership => _membership;

  static Duration? get regenerationRemaining {
    if (isGoldenMember || _lifeCount >= normalCap) return null;

    _applyAutomaticRegeneration();
    if (_lifeCount >= normalCap) return null;

    final start = _regenStart;
    if (start == null) return regenerationInterval;

    final elapsed = DateTime.now().difference(start);
    final remaining = regenerationInterval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Consume one normal life when starting a gameplay attempt.
  /// Golden members never consume life.
  static Future<bool> consumeLife() async {
    if (isGoldenMember) return true;

    _applyAutomaticRegeneration();
    if (_lifeCount <= 0) return false;

    _lifeCount--;
    if (_lifeCount < normalCap) {
      _regenStart ??= DateTime.now();
    }
    await _persist();
    return true;
  }

  /// Add purchased lives. Purchased lives may exceed the normal cap of 5.
  static Future<void> addPurchasedLives(int amount) async {
    if (amount <= 0 || isGoldenMember) return;

    _applyAutomaticRegeneration();
    _lifeCount += amount;
    if (_lifeCount >= normalCap) {
      _regenStart = null;
    }
    await _persist();
  }

  /// Set membership for the account system.
  /// Accepted values: general, premium, golden.
  static Future<void> setMembership(String membership) async {
    const allowed = {'general', 'premium', 'golden'};
    if (!allowed.contains(membership)) return;

    _membership = membership;
    if (isGoldenMember) {
      _regenStart = null;
    } else if (_lifeCount < normalCap && _regenStart == null) {
      _regenStart = DateTime.now();
    }
    await _persist();
  }

  /// Useful for development/reset flows without changing the normal rules.
  static Future<void> resetToNormal() async {
    _membership = 'general';
    _lifeCount = normalCap;
    _regenStart = null;
    await _persist();
  }

  static void _applyAutomaticRegeneration() {
    if (isGoldenMember || _lifeCount >= normalCap) {
      _regenStart = null;
      return;
    }

    _regenStart ??= DateTime.now();
    final start = _regenStart!;
    final elapsed = DateTime.now().difference(start);
    if (elapsed < regenerationInterval) return;

    final recovered = elapsed.inSeconds ~/ regenerationInterval.inSeconds;
    final newLifeCount = _lifeCount + recovered;

    if (newLifeCount >= normalCap) {
      _lifeCount = normalCap;
      _regenStart = null;
      return;
    }

    _lifeCount = newLifeCount;
    _regenStart = start.add(
      Duration(seconds: recovered * regenerationInterval.inSeconds),
    );
  }

  static Future<void> _persist() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setInt(_lifeKey, _lifeCount);
    await _preferences!.setString(_membershipKey, _membership);

    if (_regenStart == null) {
      await _preferences!.remove(_regenStartKey);
    } else {
      await _preferences!.setInt(
        _regenStartKey,
        _regenStart!.millisecondsSinceEpoch,
      );
    }
  }
}
