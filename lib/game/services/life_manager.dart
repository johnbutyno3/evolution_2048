import 'package:shared_preferences/shared_preferences.dart';

/// Local-only FREE new-game allowance and verified permanent unlock cache.
/// The legacy "life regeneration" and membership system no longer exists.
class LifeManager {
  LifeManager._();

  static const int normalCap = 5;
  static const int initialFreeGames = 5;
  static const String _freeGamesKey =
      'rebirth_2048_free_new_games_remaining_v1';
  static const String _permanentUnlockKey =
      'rebirth_2048_permanent_unlock_v1';

  static SharedPreferences? _preferences;
  static bool _initialized = false;
  static int _freeGamesRemaining = initialFreeGames;
  static bool _permanentUnlock = false;

  static Future<void> initialize() => initializeLocal();

  static Future<void> initializeLocal() async {
    _preferences = await SharedPreferences.getInstance();
    _freeGamesRemaining =
        (_preferences!.getInt(_freeGamesKey) ?? initialFreeGames)
            .clamp(0, initialFreeGames)
            .toInt();
    _permanentUnlock =
        _preferences!.getBool(_permanentUnlockKey) ?? false;
    _initialized = true;
  }

  /// Kept as a compatibility call for guest-first screens.
  static void enableGuestMode() {}

  /// Called only by a future Google Play Billing verifier after a verified
  /// permanent non-consumable purchase. Never call this from a UI simulator.
  static Future<void> applyVerifiedPermanentUnlock() async {
    await _ensureInitialized();
    final saved = await _preferences!.setBool(_permanentUnlockKey, true);
    if (!saved) {
      throw StateError('Could not persist permanent purchase entitlement.');
    }
    _permanentUnlock = true;
  }

  static Future<void> _ensureInitialized() async {
    if (!_initialized) await initializeLocal();
  }

  static bool get hasPermanentUnlock => _permanentUnlock;
  static int get freeGamesRemaining => _freeGamesRemaining;
  static bool get hasAuthoritativeState => _initialized;
  static bool get hasUnlimitedLives => _permanentUnlock;
  static bool get isGoldenMember => false;
  static String get membership => _permanentUnlock ? 'purchased' : 'free';
  static String get lifeMode => 'normal';
  static int get lifeCount => _permanentUnlock ? -1 : _freeGamesRemaining;
  static int? get nextLifeAtMillis => null;
  static Duration? get regenerationRemaining => null;

  /// Preflight only. The durable debit is committed once when a new gameId is
  /// created in PlayerProgressService.
  static bool optimisticConsumeLife() =>
      _permanentUnlock || (_initialized && _freeGamesRemaining > 0);

  /// Deduct exactly one permanent free-game allowance for a new gameId.
  /// Resuming an existing game must never call this method.
  static Future<bool> consumeFreeGame() async {
    await _ensureInitialized();
    if (_permanentUnlock) return true;
    if (_freeGamesRemaining <= 0) return false;

    final previous = _freeGamesRemaining;
    final next = previous - 1;
    final saved = await _preferences!.setInt(_freeGamesKey, next);
    if (!saved) return false;
    _freeGamesRemaining = next;
    return true;
  }

  /// Roll back only if a new game failed to become playable after its debit.
  static Future<void> refundFailedGameCreation() async {
    await _ensureInitialized();
    if (_permanentUnlock || _freeGamesRemaining >= initialFreeGames) return;
    final next = _freeGamesRemaining + 1;
    final saved = await _preferences!.setInt(_freeGamesKey, next);
    if (!saved) {
      throw StateError('Could not restore failed new-game debit.');
    }
    _freeGamesRemaining = next;
  }

  /// Compatibility method for older callers; it now means one new game.
  static Future<bool> consumeLife() => consumeFreeGame();

  /// Chapter completion never refunds a FREE new-game allowance.
  static Future<void> refundChapterCompletionLife() async {}

  /// Compatibility alias used by the old progression service. No server call
  /// is performed in the offline edition.
  static Future<void> refreshFromServer({bool fromRegeneration = false}) =>
      initializeLocal();

  /// The offline edition has no regeneration timer.
  static void tickRegeneration() {}

  /// Does not erase actual local entitlement data.
  static void clearCachedState() {
    _preferences = null;
    _initialized = false;
  }
}
