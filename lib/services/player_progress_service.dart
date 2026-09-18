import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/life_manager.dart';

/// Server-authoritative account progression.
class PlayerProgressService {
  PlayerProgressService._();

  static final PlayerProgressService instance = PlayerProgressService._();

  static const String _progressCollection = 'progress';
  static const String _progressDocument = 'game';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  int _unlockedChapterIndex = 0;
  bool _loadedFromServer = false;
  String? _activeGameSessionId;
  int? _activeGameChapterIndex;

  int get unlockedChapterIndex => _unlockedChapterIndex;
  bool get loadedFromServer => _loadedFromServer;
  String? get activeGameSessionId => _activeGameSessionId;
  int? get activeGameChapterIndex => _activeGameChapterIndex;
  bool get hasUnfinishedGame => _activeGameSessionId != null;

  bool isChapterUnlocked(int chapterIndex) {
    return chapterIndex >= 0 &&
        chapterIndex <= _unlockedChapterIndex &&
        !isChapterBlockedByUnfinishedGame(chapterIndex);
  }

  bool isChapterBlockedByUnfinishedGame(int chapterIndex) {
    final activeChapter = _activeGameChapterIndex;
    return activeChapter != null && activeChapter != chapterIndex;
  }

  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      _unlockedChapterIndex = 0;
      _loadedFromServer = false;
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(_progressCollection)
          .doc(_progressDocument)
          .get(const GetOptions(source: Source.server));

      final data = snapshot.data() ?? <String, dynamic>{};
      final value = data['unlockedChapterIndex'];
      _unlockedChapterIndex = value is num ? value.toInt().clamp(0, 5) : 0;

      final sessionId = data['activeGameSessionId'];
      _activeGameSessionId = sessionId is String && sessionId.isNotEmpty
          ? sessionId
          : null;

      final activeChapter = data['activeGameChapterIndex'];
      _activeGameChapterIndex = activeChapter is num
          ? activeChapter.toInt().clamp(0, 5)
          : null;

      _loadedFromServer = true;
    } on FirebaseException {
      _loadedFromServer = false;
    }
  }

  Future<bool> startGameSession(
    int chapterIndex, {
    bool replaceActiveSession = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    try {
      final result = await _functions.httpsCallable('startGameSession').call({
        'chapterIndex': chapterIndex,
        'replaceActiveSession': replaceActiveSession,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        final returnedChapter = data['chapterIndex'];
        _activeGameChapterIndex = returnedChapter is num
            ? returnedChapter.toInt().clamp(0, 5)
            : chapterIndex;
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      // Keep the authoritative server error visible in browser/dev logs.
      // Callable errors include the server code/message/details, which is
      // essential for distinguishing Life exhaustion from session failures.
      // ignore: avoid_print
      print(
        'startGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (replaceActiveSession) clearGameSession();
    }
    return false;
  }

  /// Re-enters the server-owned unfinished session.
  ///
  /// Re-entry is a billable game entry under the Life rules, but it must
  /// preserve the same server session/board. The server performs the Life
  /// deduction atomically with session validation so a failed resume cannot
  /// consume a Life.
  Future<bool> resumeGameSession(int chapterIndex) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    try {
      final result = await _functions.httpsCallable('resumeGameSession').call({
        'chapterIndex': chapterIndex,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        final returnedChapter = data['chapterIndex'];
        _activeGameChapterIndex = returnedChapter is num
            ? returnedChapter.toInt().clamp(0, 5)
            : chapterIndex;
        await LifeManager.refreshFromServer();
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      // A failed resume must never silently become a new game attempt.
      // Keep the authoritative server error visible for diagnosis.
      // ignore: avoid_print
      print(
        'resumeGameSession failed: code=' + error.code + ', '
        'message=' + (error.message ?? 'null') + ', '
        'details=' + (error.details?.toString() ?? 'null'),
      );
      await refresh();
    }
    return false;
  }

  Future<bool> restartGameSession(int chapterIndex) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    try {
      final result = await _functions.httpsCallable('restartGameSession').call({
        'chapterIndex': chapterIndex,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        _activeGameChapterIndex = chapterIndex;
        await LifeManager.refreshFromServer();
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      // Callable errors preserve the server-side reason. Log it instead of
      // swallowing it so a failed restart can be diagnosed from the browser
      // console without guessing which precondition failed.
      // ignore: avoid_print
      print(
        'restartGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      await refresh();
    }
    return false;
  }

  Future<void> abandonGameSession() async {
    // Reconcile first so Game Over -> Home cannot use a stale/null local
    // session id while the server still owns the active attempt.
    await refresh();
    final sessionId = _activeGameSessionId;
    if (sessionId == null) return;

    try {
      await _functions.httpsCallable('abandonGameSession').call({
        'sessionId': sessionId,
      });

      // The callable succeeded, so the server has ended this session.
      // Clear the local cache immediately and then verify against the
      // server. This avoids a stale Firestore cache making the next entry
      // look like an unfinished game.
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      await refresh();
    } on FirebaseFunctionsException catch (error) {
      // Keep the server error visible during development. Do not clear the
      // local session when the server did not confirm abandonment.
      // ignore: avoid_print
      print(
        'abandonGameSession failed: code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details?.toString() ?? 'null'}',
      );
    }
  }

  /// Clears the local cache, then immediately reconciles it with the server.
  /// This prevents legacy callers that clear during page startup from erasing
  /// a valid server-owned unfinished session and bypassing Life protection.
  void clearGameSession() {
    _activeGameSessionId = null;
    _activeGameChapterIndex = null;
    unawaited(refresh());
  }

  Future<bool> completeChapter({
    required int chapterIndex,
    required Map<String, dynamic> replayLog,
  }) async {
    final user = _auth.currentUser;
    final sessionId = _activeGameSessionId;
    if (user == null || sessionId == null) return false;

    try {
      final result = await _functions.httpsCallable('completeChapter').call({
        'sessionId': sessionId,
        'chapterIndex': chapterIndex,
        'replayLog': replayLog,
      });
      final data = result.data;
      if (data is Map && data['unlockedChapterIndex'] is num) {
        _unlockedChapterIndex =
            (data['unlockedChapterIndex'] as num).toInt().clamp(0, 5);
        _loadedFromServer = true;
        clearGameSession();
        return true;
      }
    } on FirebaseFunctionsException {
      return false;
    }
    return false;
  }
}
