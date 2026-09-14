import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Server-authoritative account progression.
///
/// SharedPreferences remains responsible for the local/offline game board.
/// This service is the authority for chapter unlock state. The client never
/// writes the progress document directly.
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

  int get unlockedChapterIndex => _unlockedChapterIndex;
  bool get loadedFromServer => _loadedFromServer;
  String? get activeGameSessionId => _activeGameSessionId;

  bool isChapterUnlocked(int chapterIndex) {
    return chapterIndex >= 0 && chapterIndex <= _unlockedChapterIndex;
  }

  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      _unlockedChapterIndex = 0;
      _loadedFromServer = false;
      _activeGameSessionId = null;
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

      _loadedFromServer = true;
    } on FirebaseException {
      _loadedFromServer = false;
    }
  }

  /// Starts a new server-side gameplay session for one chapter attempt.
  ///
  /// The session ID is kept only in memory. It is never stored in the local
  /// gameplay save, so an old completion token cannot be replayed later.
  Future<bool> startGameSession(int chapterIndex) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('startGameSession');
      final result = await callable.call(<String, dynamic>{
        'chapterIndex': chapterIndex,
      });

      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        return true;
      }
    } on FirebaseFunctionsException {
      _activeGameSessionId = null;
    }

    return false;
  }

  /// Clears the in-memory session when the account/game leaves the attempt.
  void clearGameSession() {
    _activeGameSessionId = null;
  }

  /// Requests a server-side chapter unlock after a completed chapter.
  ///
  /// The callable function requires the server-issued gameplay session and
  /// consumes that session exactly once. The fallback session creation keeps
  /// existing clients functional until the gameplay screen explicitly starts
  /// a session at the beginning of an attempt.
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
        _activeGameSessionId = null;
        return true;
      }
    } on FirebaseFunctionsException {
      return false;
    }

    return false;
  }
}
