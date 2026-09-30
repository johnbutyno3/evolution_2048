import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Owns account profile and chapter progression only.
///
/// Gameplay lifecycle is owned by GameLifecycleManager. This service never
/// starts, resumes, restarts, abandons, or saves a game session.
class PlayerProgressService {
  PlayerProgressService._();

  static final PlayerProgressService instance = PlayerProgressService._();

  static const List<String> _chapterNames = <String>[
    'ocean',
    'land',
    'sky',
    'history',
    'tech',
    'universe',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _unlockedChapterIndex = 0;
  final Map<String, Map<String, int>> _chapterProgress =
      <String, Map<String, int>>{};
  bool _loadedFromServer = false;

  int get unlockedChapterIndex => _unlockedChapterIndex;
  bool get loadedFromServer => _loadedFromServer;

  int chapterHighestValue(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapterNames.length) return 0;
    return _chapterProgress[_chapterNames[chapterIndex]]?['highestValue'] ?? 0;
  }

  int chapterScore(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapterNames.length) return 0;
    return _chapterProgress[_chapterNames[chapterIndex]]?['score'] ?? 0;
  }

  bool isChapterUnlocked(int chapterIndex) =>
      chapterIndex >= 0 && chapterIndex <= _unlockedChapterIndex;

  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      clearLocalState();
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc('game')
          .get(const GetOptions(source: Source.server));

      final data = snapshot.data() ?? <String, dynamic>{};
      final unlocked = data['unlockedChapterIndex'];
      _unlockedChapterIndex =
          unlocked is num ? unlocked.toInt().clamp(0, 5) : 0;

      _chapterProgress.clear();
      final rawProgress = data['chapterProgress'];
      if (rawProgress is Map) {
        for (final entry in rawProgress.entries) {
          if (entry.value is! Map) continue;
          final value = entry.value as Map;
          final highest = value['highestValue'];
          final score = value['score'];
          _chapterProgress[entry.key.toString()] = <String, int>{
            'highestValue': highest is num ? highest.toInt() : 0,
            'score': score is num ? score.toInt() : 0,
          };
        }
      }
      _loadedFromServer = true;
    } on FirebaseException {
      _loadedFromServer = false;
    }
  }

  void clearLocalState() {
    _unlockedChapterIndex = 0;
    _chapterProgress.clear();
    _loadedFromServer = false;
  }
}
