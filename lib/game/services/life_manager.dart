import 'package:cloud_functions/cloud_functions.dart';

/// Local-first life presentation with server verification.
///
/// Gameplay uses an optimistic local decrement so entering a game never waits
/// for Firebase. Firebase remains authoritative and every successful session
/// response reconciles the local state with the server state.
class LifeManager {
  LifeManager._();

  static const int normalCap = 5;
  static const int _regenIntervalMillis = 40 * 60 * 1000;

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static int _lifeCount = normalCap;
  static bool _infiniteLives = false;
  static String _membership = 'general';
  static String _lifeMode = 'normal';
  static int? _nextLifeAtMillis;
  static bool _regenerationSyncInFlight = false;

  static Future<void> initialize() async {
    await refreshFromServer();
  }

  /// Applies an authoritative life payload returned by a server mutation.
  static void applyServerState(Map<String, dynamic> data) {
    _applyServerState(data);
  }

  /// Immediately consumes one local Life for game entry.
  ///
  /// This is intentionally optimistic: the server transaction is still sent
  /// by PlayerProgressService in the background. A known-empty local state is
  /// rejected immediately; otherwise the server response is authoritative and
  /// replaces this value.
  static bool optimisticConsumeLife() {
    if (_infiniteLives) return true;
    if (_lifeCount <= 0) return false;

    final nextLives = _lifeCount - 1;
    _lifeCount = nextLives;
    _nextLifeAtMillis = nextLives < normalCap
        ? (_nextLifeAtMillis ??
            DateTime.now().millisecondsSinceEpoch + _regenIntervalMillis)
        : null;
    return true;
  }

  static Future<void> refreshFromServer() async {
    final result = await _functions.httpsCallable('getLifeState').call();
    _applyServerState(Map<String, dynamic>.from(result.data as Map));
  }

  static void _applyServerState(Map<String, dynamic> data) {
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

    _lifeCount = lives;
    _infiniteLives = infiniteLives;
    _membership = membership as String;
    _lifeMode = lifeMode as String;
    _nextLifeAtMillis = nextLifeAtMillis as int?;
  }

  static bool get isGoldenMember => _lifeMode == 'golden';

  static String get lifeMode => _lifeMode;

  static int get lifeCount => _infiniteLives ? -1 : _lifeCount;

  static String get membership => _membership;

  static int? get nextLifeAtMillis =>
      _infiniteLives ? null : _nextLifeAtMillis;

  /// Advances the local regeneration state as soon as the countdown expires.
  ///
  /// The local transition is immediate so the UI never remains at
  /// "4 (00:00)" while waiting for Firebase. The server is then queried in
  /// the background and remains authoritative for the final state.
  static void tickRegeneration() {
    if (_infiniteLives || _lifeCount < 0 || _nextLifeAtMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _nextLifeAtMillis!) return;

    final elapsed = now - _nextLifeAtMillis!;
    final recovered = 1 + (elapsed ~/ _regenIntervalMillis);
    final nextLives = (_lifeCount + recovered).clamp(0, normalCap);
    _lifeCount = nextLives;

    if (_lifeCount >= normalCap) {
      _nextLifeAtMillis = null;
    } else {
      _nextLifeAtMillis =
          _nextLifeAtMillis! + recovered * _regenIntervalMillis;
    }

    if (_regenerationSyncInFlight) return;
    _regenerationSyncInFlight = true;
    refreshFromServer().catchError((_) {
      // Keep the optimistic local regeneration visible if Firebase is
      // temporarily unavailable. A later tick/reload will retry.
    }).whenComplete(() {
      _regenerationSyncInFlight = false;
    });
  }

  static Duration? get regenerationRemaining {
    final next = nextLifeAtMillis;
    if (next == null) return null;

    final remaining =
        Duration(milliseconds: next - DateTime.now().millisecondsSinceEpoch);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Legacy explicit server consume API. Normal game entry now uses the
  /// local-first session flow instead of waiting for this call.
  static Future<bool> consumeLife() async {
    try {
      final result = await _functions.httpsCallable('consumeLife').call();
      _applyServerState(Map<String, dynamic>.from(result.data as Map));
      return true;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' &&
          error.message == 'No lives available.') {
        await refreshFromServer();
        return false;
      }
      rethrow;
    }
  }

  static Future<void> refundChapterCompletionLife() async {
    final result = await _functions.httpsCallable('refundLife').call();
    _applyServerState(Map<String, dynamic>.from(result.data as Map));
  }
}
