import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/game_engine.dart';
import '../game/services/life_manager.dart';

/// Server-authoritative account progression.
///
/// SharedPreferences remains responsible for the local/offline game board.
/// This service is the authority for chapter unlock state and active gameplay
/// session ownership. The client never writes protected progress directly.
class PlayerProgressService {
  PlayerProgressService._();

  static final PlayerProgressService instance = PlayerProgressService._();

  static const String _progressCollection = 'progress';
  static const String _progressDocument = 'game';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

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
    return chapterIndex >= 0 && chapterIndex <= _unlockedChapterIndex;
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
          .get();

      final value = snapshot.data()?['unlockedChapterIndex'];
      if (value is num) {
        _unlockedChapterIndex = value.toInt().clamp(0, 5);
      } else {
        _unlockedChapterIndex = 0;
      }

      final sessionId = snapshot.data()?['activeGameSessionId'];
      _activeGameSessionId = sessionId is String && sessionId.isNotEmpty
          ? sessionId
          : null;

      final activeChapter = snapshot.data()?['activeGameChapterIndex'];
      _activeGameChapterIndex = activeChapter is num
          ? activeChapter.toInt().clamp(0, 5)
          : null;

      _loadedFromServer = true;
    } on FirebaseException {
      _loadedFromServer = false;
    }
  }

  /// Starts or resumes the server-side gameplay session for one chapter.
  Future<bool> startGameSession(
    int chapterIndex, {
    bool replaceActiveSession = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('startGameSession');
      final result = await callable.call(<String, dynamic>{
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
    } on FirebaseFunctionsException {
      if (replaceActiveSession) {
        _activeGameSessionId = null;
        _activeGameChapterIndex = null;
      }
    }

    return false;
  }

  /// Atomically consumes one Life, replaces the old active session, and
  /// creates the new session. No new board should be created before this
  /// succeeds.
  Future<bool> restartGameSession(int chapterIndex) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('restartGameSession');
      final result = await callable.call(<String, dynamic>{
        'chapterIndex': chapterIndex,
      });

      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        _activeGameChapterIndex = chapterIndex;

        // The server has already consumed the Life atomically. Mark that
        // server-confirmed consumption for the existing synchronous engine
        // bridge; this does not perform another server mutation.
        LifeManager.acknowledgeServerConsumedLife();

        return true;
      }
    } on FirebaseFunctionsException {
      await refresh();
    }

    return false;
  }

  /// Releases an active session after Game Over.
  Future<void> abandonGameSession() async {
    final sessionId = _activeGameSessionId;
    if (sessionId == null) {
      return;
    }

    try {
      final callable = _functions.httpsCallable('abandonGameSession');
      await callable.call(<String, dynamic>{'sessionId': sessionId});
    } on FirebaseFunctionsException {
      // The local copy is still cleared so the current UI cannot retain a
      // dead session token. The server remains authoritative on next entry.
    } finally {
      clearGameSession();
    }
  }

  /// Clears only the in-memory copy after the server has ended the session.
  /// Never call this merely because the gameplay page was popped to Home.
  void clearGameSession() {
    _activeGameSessionId = null;
    _activeGameChapterIndex = null;
  }

  Future<bool> completeChapter({
    required int chapterIndex,
    required Map<String, dynamic> replayLog,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    final sessionId = _activeGameSessionId;
    if (sessionId == null) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('completeChapter');
      final result = await callable.call(<String, dynamic>{
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

/// Keeps the existing GameEngine API call site while the authoritative Life
/// mutation remains on the server. This is an extension because the engine's
/// core implementation is intentionally kept focused on local board state.
extension ServerRestartGameEngineBridge on GameEngine {
  void markBoardLifeActiveAfterServerRestart() {
    if (!consumeLifeForGameEntry()) {
      return;
    }

    startGameTimer();
  }
}
