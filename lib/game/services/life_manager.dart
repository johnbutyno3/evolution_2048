import '../../services/supabase_account_service.dart';
import '../../services/supabase_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first life presentation with Supabase account-snapshot verification.
/// Gameplay uses an optimistic decrement; session RPCs remain authoritative.
class LifeManager {
  LifeManager._();

  static const int normalCap = 5;
  static const String _freeGamesKey = 'rebirth_2048_free_new_games_remaining_v1';
  static const String _permanentUnlockKey = 'rebirth_2048_permanent_unlock_v1';
  static const int initialFreeGames = 5;
  static SharedPreferences? _preferences;
  static bool _guestMode = true;
  static bool _localStateInitialized = false;
  static int _freeGamesRemaining = initialFreeGames;
  static bool _permanentUnlock = false;

  static int _lifeCount = normalCap;
  static bool _hasAuthoritativeState = false;
  static bool _infiniteLives = false;
  static String _membership = 'general';
  static String _lifeMode = 'normal';
  static int? _nextLifeAtMillis;
  static int _lifeStateGeneration = 0;

  /// Loads the permanent local free-new-game allowance and Play entitlement cache.
  /// This must run before the first Home screen is shown.
  static Future<void> initializeLocal() async {
    _preferences = await SharedPreferences.getInstance();
    _freeGamesRemaining = (_preferences!.getInt(_freeGamesKey) ?? initialFreeGames)
        .clamp(0, initialFreeGames);
    _permanentUnlock = _preferences!.getBool(_permanentUnlockKey) ?? false;
    _localStateInitialized = true;
    enableGuestMode();
  }

  /// Guest play is local-only. FREE has five lifetime new-game starts, not lives.
  static void enableGuestMode() {
    _guestMode = true;
    _lifeStateGeneration++;
    _lifeCount = _permanentUnlock ? -1 : _freeGamesRemaining;
    _infiniteLives = _permanentUnlock;
    _membership = 'general';
    _lifeMode = 'normal';
    _nextLifeAtMillis = null;
    _hasAuthoritativeState = _localStateInitialized;
  }

  /// Called only after Google Play Billing has verified the permanent product.
  static Future<void> applyVerifiedPermanentUnlock() async {
    _preferences ??= await SharedPreferences.getInstance();
    final saved = await _preferences!.setBool(_permanentUnlockKey, true);
    if (!saved) throw StateError('Could not persist permanent purchase entitlement.');
    _permanentUnlock = true;
    enableGuestMode();
  }

  static bool get hasPermanentUnlock => _permanentUnlock;
  static int get freeGamesRemaining => _freeGamesRemaining;

  /// Atomically persists one new-game debit. Resuming the same game never calls this.
  static Future<bool> consumeFreeGame() async {
    if (!_localStateInitialized) await initializeLocal();
    if (_permanentUnlock) return true;
    if (_freeGamesRemaining <= 0) return false;
    final previous = _freeGamesRemaining;
    _freeGamesRemaining = previous - 1;
    try {
      final saved = await _preferences!.setInt(_freeGamesKey, _freeGamesRemaining);
      if (!saved) throw StateError('Could not persist free-game allowance.');
      _lifeCount = _freeGamesRemaining;
      _lifeStateGeneration++;
      return true;
    } catch (_) {
      _freeGamesRemaining = previous;
      _lifeCount = previous;
      return false;
    }
  }

  /// Roll back only when creating a new game failed before it became playable.
  static Future<void> refundFailedGameCreation() async {
    if (!_localStateInitialized) await initializeLocal();
    if (_permanentUnlock || _freeGamesRemaining >= initialFreeGames) return;
    final next = _freeGamesRemaining + 1;
    final saved = await _preferences!.setInt(_freeGamesKey, next);
    if (!saved) throw StateError('Could not restore failed new-game debit.');
    _freeGamesRemaining = next;
    _lifeCount = next;
    _lifeStateGeneration++;
  }

  static Future<void> initialize() async {
    await refreshFromServer();
  }

  /// Applies the life entitlement from the validated Supabase account snapshot.
  /// This is a local cache update only; the snapshot was already verified by
  /// the trusted account-snapshot Edge Function.
  static void applySupabaseSnapshot({
    required int lives,
    required bool unlimited,
    required String membershipTier,
    required DateTime? nextRegenAt,
  }) {
    _guestMode = false;
    if (lives < 0) throw ArgumentError.value(lives, 'lives');
    if (!const {'FREE', 'PREMIUM', 'GOLDEN'}.contains(membershipTier)) {
      throw ArgumentError.value(membershipTier, 'membershipTier');
    }
    _lifeStateGeneration++;
    _lifeCount = lives;
    _infiniteLives = unlimited;
    _membership = switch (membershipTier) {
      'PREMIUM' => 'premium',
      'GOLDEN' => 'golden',
      _ => 'general',
    };
    _lifeMode = membershipTier == 'GOLDEN' ? 'golden' : 'normal';
    _nextLifeAtMillis = nextRegenAt?.millisecondsSinceEpoch;
    _hasAuthoritativeState = true;
  }

  /// Applies an authoritative life payload returned by a server mutation.
  /// Any in-flight regeneration read becomes stale and may no longer
  /// overwrite this newer mutation result.
  static void applyServerState(Map<String, dynamic> data) {
    _lifeStateGeneration++;
    _applyServerState(data);
  }

  /// Immediately consumes one local Life for game entry.
  ///
  /// This is intentionally optimistic: the server transaction is still sent
  /// by PlayerProgressService in the background. A known-empty local state is
  /// rejected immediately; otherwise the server response is authoritative and
  /// replaces this value.
  static bool optimisticConsumeLife() {
    // In local guest mode this is a preflight check only. The actual persistent
    // debit is performed once by PlayerProgressService when a new gameId is committed.
    if (_guestMode) return _permanentUnlock || _freeGamesRemaining > 0;
    // Never charge from the placeholder balance before the server has
    // confirmed this account's actual life state.
    if (!_hasAuthoritativeState) return false;
    if (_infiniteLives) return true;
    if (_lifeCount <= 0) return false;

    final nextLives = _lifeCount - 1;
    _lifeCount = nextLives;
    _nextLifeAtMillis = null;
    _lifeStateGeneration++;
    return true;
  }

  /// Reads the authoritative state. Every request is tied to the generation
  /// that existed when it started, so an older response can never overwrite a
  /// newer local mutation or server mutation.
  static Future<void> refreshFromServer({bool fromRegeneration = false}) async {
    if (!SupabaseBackend.isAuthenticated) {
      if (!_localStateInitialized) await initializeLocal();
      enableGuestMode();
      return;
    }
    final requestGeneration = fromRegeneration
        ? _lifeStateGeneration
        : ++_lifeStateGeneration;

    try {
      final snapshot = await SupabaseAccountService.fetchSnapshot();
      if (requestGeneration != _lifeStateGeneration) return;
      _lifeCount = snapshot.lifeCount;
      _infiniteLives = snapshot.unlimitedLives;
      _membership = switch (snapshot.membershipTier) {
        'PREMIUM' => 'premium',
        'GOLDEN' => 'golden',
        _ => 'general',
      };
      _lifeMode = snapshot.membershipTier == 'GOLDEN' ? 'golden' : 'normal';
      _nextLifeAtMillis = snapshot.nextRegenAt?.millisecondsSinceEpoch;
      _hasAuthoritativeState = true;
    } on SupabaseAccountException {
      // A failed snapshot is not permission to change the cached life balance.
      rethrow;
    }
  }

  static void _applyServerState(
    Map<String, dynamic> data, {
    bool preserveLocalRegeneration = false,
  }) {
    final lives = data['lives'];
    final infiniteLives = data['infiniteLives'] == true;
    final membership = data['membership'];
    final lifeMode = data['lifeMode'];
    final nextLifeAtMillis = data['nextLifeAtMillis'];

    if (lives is! int || lives < -1) {
      throw StateError('Invalid server life state.');
    }

    if (lifeMode != 'normal' && lifeMode != 'golden') {
      throw StateError('Invalid server life mode.');
    }

    if (membership != 'general' &&
        membership != 'premium' &&
        membership != 'golden') {
      throw StateError('Invalid server membership state.');
    }

    if (nextLifeAtMillis != null && nextLifeAtMillis is! int) {
      throw StateError('Invalid server regeneration timestamp.');
    }

    final localLives = _lifeCount;
    final localNextLifeAtMillis = _nextLifeAtMillis;
    final preserveOptimisticLife =
        preserveLocalRegeneration &&
        !_infiniteLives &&
        !infiniteLives &&
        lives < localLives &&
        localNextLifeAtMillis != null;

    _lifeCount = preserveOptimisticLife ? localLives : lives;
    _infiniteLives = infiniteLives;
    _membership = membership as String;
    _lifeMode = lifeMode as String;
    _nextLifeAtMillis = preserveOptimisticLife
        ? localNextLifeAtMillis
        : nextLifeAtMillis as int?;
    _hasAuthoritativeState = true;
  }

  /// Clears account-scoped local state before Supabase sign-out.
  /// The next account must never inherit the previous account's Life display.
  static void clearCachedState() {
    _lifeStateGeneration++;
    _hasAuthoritativeState = false;
    _lifeCount = normalCap;
    _infiniteLives = false;
    _membership = 'general';
    _lifeMode = 'normal';
    _nextLifeAtMillis = null;
  }

  static bool get hasAuthoritativeState => _hasAuthoritativeState;

  static bool get isGoldenMember => !_guestMode && _lifeMode == 'golden';

  static bool get hasUnlimitedLives => _guestMode ? _permanentUnlock : _infiniteLives;

  static String get lifeMode => _lifeMode;

  static int get lifeCount => _guestMode ? (_permanentUnlock ? -1 : _freeGamesRemaining) : (_infiniteLives ? -1 : _lifeCount);

  static String get membership => _membership;

  static int? get nextLifeAtMillis =>
      _guestMode || _infiniteLives ? null : _nextLifeAtMillis;

  /// Advances the local regeneration state as soon as the countdown expires.
  ///
  /// The local transition is immediate so the UI never remains at
  /// "4 (00:00)" while waiting for Supabase. The server is then queried in
  /// the background. A stale response can no longer roll the just-regenerated
  /// Life back down.
  static void tickRegeneration() {
    // Regeneration is removed from the single-player product rules.
    if (_guestMode) return;
    if (_infiniteLives || _lifeCount < 0 || _nextLifeAtMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _nextLifeAtMillis!) return;

    final elapsed = now - _nextLifeAtMillis!;
    final recovered = 1 + (elapsed ~/ _regenIntervalMillis);
    final nextLives = (_lifeCount + recovered).clamp(0, normalCap).toInt();
    _lifeCount = nextLives;

    if (_lifeCount >= normalCap) {
      _nextLifeAtMillis = null;
    } else {
      _nextLifeAtMillis =
          _nextLifeAtMillis! + recovered * _regenIntervalMillis;
    }

    // This local mutation invalidates every older life read. Always issue the
    // background verification, even if a previous regeneration request is
    // still in flight; the older request will be discarded by generation.
    _lifeStateGeneration++;
    refreshFromServer(fromRegeneration: true).catchError((_) {
      // Keep the optimistic local regeneration visible if Supabase is
      // temporarily unavailable. A later refresh/re-entry will retry.
    });
  }

  static Duration? get regenerationRemaining {
    if (_guestMode) return null;
    final next = nextLifeAtMillis;
    if (next == null) return null;

    final remaining =
        Duration(milliseconds: next - DateTime.now().millisecondsSinceEpoch);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Life is deducted only by start/restart-game-session transactions.
  /// Kept as a compatibility guard so callers cannot double-charge life.
  static Future<bool> consumeLife() async {
    throw UnsupportedError(
      'Life can only be consumed by an authoritative game-session transaction.',
    );
  }

  /// Chapter completion life is settled by finish-game-chapter on the server.
  static Future<void> refundChapterCompletionLife() async {
    throw UnsupportedError(
      'Chapter completion life is settled by the game-session transaction.',
    );
  }

}
