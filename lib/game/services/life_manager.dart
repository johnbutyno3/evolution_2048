import 'package:cloud_functions/cloud_functions.dart';

/// Server-authoritative life state for Evolution 2048.
///
/// The client keeps only a presentation cache. Life count, membership and
/// regeneration timing are resolved by Firebase Functions and Firestore.
/// The client never grants, consumes, refunds or otherwise mutates life state
/// locally.
class LifeManager {
  LifeManager._();

  static const int normalCap = 5;

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static int _lifeCount = normalCap;
  static bool _infiniteLives = false;
  static String _membership = 'general';
  static int? _nextLifeAtMillis;
  static bool _initialized = false;

  // Compatibility bridge for the existing synchronous GameEngine API.
  // The actual life mutation is still performed by the server. A successful
  // consumeLife() reserves one server-confirmed consumption for the engine
  // call that immediately follows it, preventing a second server deduction.
  static bool _engineLifeConsumptionPending = false;

  static Future<void> initialize() async {
    await refreshFromServer();
  }

  static Future<void> refreshFromServer() async {
    final result = await _functions.httpsCallable('getLifeState').call();
    _applyServerState(Map<String, dynamic>.from(result.data as Map));
    _initialized = true;
  }

  static void _applyServerState(Map<String, dynamic> data) {
    final lives = data['lives'];
    final infiniteLives = data['infiniteLives'] == true;
    final membership = data['membership'];
    final nextLifeAtMillis = data['nextLifeAtMillis'];

    if (lives is! int || lives < -1) {
      throw StateError('Invalid server life state.');
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
    _nextLifeAtMillis = nextLifeAtMillis as int?;
  }

  static bool get isInitialized => _initialized;

  static bool get isGoldenMember => _infiniteLives;

  static int get lifeCount => _infiniteLives ? -1 : _lifeCount;

  static String get membership => _membership;

  static int? get nextLifeAtMillis =>
      _infiniteLives ? null : _nextLifeAtMillis;

  static Duration? get regenerationRemaining {
    final next = nextLifeAtMillis;
    if (next == null) return null;

    final remaining =
        Duration(milliseconds: next - DateTime.now().millisecondsSinceEpoch);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static const Duration regenerationInterval = Duration(hours: 1);

  static Future<bool> consumeLife() async {
    try {
      final result = await _functions.httpsCallable('consumeLife').call();
      _applyServerState(Map<String, dynamic>.from(result.data as Map));
      _initialized = true;
      _engineLifeConsumptionPending = true;
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

  /// Marks a server-confirmed Life consumption for the existing synchronous
  /// GameEngine bridge. This does not mutate server state.
  static void acknowledgeServerConsumedLife() {
    _engineLifeConsumptionPending = true;
  }

  static bool consumeLifeNow() {
    if (!_engineLifeConsumptionPending) {
      return false;
    }

    _engineLifeConsumptionPending = false;
    return true;
  }

  static Future<void> refundChapterCompletionLife() async {
    final result = await _functions.httpsCallable('refundLife').call();
    _applyServerState(Map<String, dynamic>.from(result.data as Map));
    _initialized = true;
  }

  /// Developer-only test helper. The actual refill is performed by the
  /// server-authoritative callable; this method never changes life locally.
  static Future<void> restoreFiveLivesForDeveloper() async {
    final result = await _functions
        .httpsCallable('restoreFiveLivesForDeveloper')
        .call();
    _applyServerState(Map<String, dynamic>.from(result.data as Map));
    _initialized = true;
  }

  static Future<void> refresh() async {
    await refreshFromServer();
  }
}
