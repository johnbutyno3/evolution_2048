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

  int get unlockedChapterIndex => _unlockedChapterIndex;
  bool get loadedFromServer => _loadedFromServer;

  bool isChapterUnlocked(int chapterIndex) {
    return chapterIndex >= 0 && chapterIndex <= _unlockedChapterIndex;
  }

  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      _unlockedChapterIndex = 0;
      _loadedFromServer = false;
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

  /// Requests a server-side chapter unlock after a completed chapter.
  ///
  /// The callable function is intentionally the only client write path.
  /// Stronger anti-cheat validation of the game session/result will be added
  /// to this server operation before rewards are introduced.
  Future<bool> completeChapter({
    required int chapterIndex,
    required int highestValue,
    required int score,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('completeChapter');
      final result = await callable.call(<String, dynamic>{
        'chapterIndex': chapterIndex,
        'highestValue': highestValue,
        'score': score,
      });

      final data = result.data;
      if (data is Map && data['unlockedChapterIndex'] is num) {
        _unlockedChapterIndex =
            (data['unlockedChapterIndex'] as num).toInt().clamp(0, 5);
        _loadedFromServer = true;
        return true;
      }
    } on FirebaseFunctionsException {
      return false;
    }

    return false;
  }
}
