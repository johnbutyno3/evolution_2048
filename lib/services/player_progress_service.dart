import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';

/// Server-authoritative account progression.
class PlayerProgressService {
  PlayerProgressService._();

  static final PlayerProgressService instance = PlayerProgressService._();

  static const String _progressCollection = 'progress';
  static const String _progressDocument = 'game';
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
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  int _unlockedChapterIndex = 0;
  final Map<String, Map<String, int>> _chapterProgress = {};
  bool _loadedFromServer = false;
  String? _activeGameSessionId;
  int? _activeGameChapterIndex;

  int get unlockedChapterIndex => _unlockedChapterIndex;
  int chapterHighestValue(int chapterIndex) =>
      _chapterProgress[_chapterNames[chapterIndex]]?['highestValue'] ?? 0;
  int chapterScore(int chapterIndex) =>
      _chapterProgress[_chapterNames[chapterIndex]]?['score'] ?? 0;
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
      _chapterProgress.clear();
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

      _chapterProgress.clear();
      final chapterProgress = data['chapterProgress'];
      if (chapterProgress is Map) {
        for (final entry in chapterProgress.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final highest = value['highestValue'];
          final score = value['score'];
          _chapterProgress[entry.key.toString()] = {
            'highestValue': highest is num ? highest.toInt() : 0,
            'score': score is num ? score.toInt() : 0,
          };
        }
      }

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
        await SaveManager.setGameSessionId(_activeGameSessionId!);
        final returnedChapter = data['chapterIndex'];
        _activeGameChapterIndex = returnedChapter is num
            ? returnedChapter.toInt().clamp(0, 5)
            : chapterIndex;
        final lifeState = data['life'];
        if (lifeState is Map) {
          LifeManager.applyServerState(
            Map<String, dynamic>.from(lifeState),
          );
        } else {
          await LifeManager.refreshFromServer();
        }
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
      if (replaceActiveSession) await refresh();
    }
    return false;
  }

  /// Re-enters the server-owned unfinished session.
  ///
  /// A normal unfinished exit keeps a local board snapshot. Game Over -> Back
  /// clears that chapter snapshot. If the server still exposes an ended/stale
  /// active session while no playable local board remains, this is a fresh
  /// game entry and must use startGameSession instead of resume.
  Future<bool> resumeGameSession(int chapterIndex) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    final chapterName = _chapterNames[chapterIndex];
    final saved = SaveManager.loadCached(chapter: chapterName);
    final hasPlayableLocalBoard = saved != null &&
        saved['gameSessionId'] == _activeGameSessionId &&
        saved['gameOver'] != true &&
        saved['chapterComplete'] != true &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == 16;

    if (!hasPlayableLocalBoard) {
      // The server may still own an unfinished session even when the local
      // board cache is missing. In that case this is a fresh entry, not a
      // resumable board: replace the orphaned same-chapter session atomically
      // and charge exactly one Life for the new game.
      return startGameSession(
        chapterIndex,
        replaceActiveSession: true,
      );
    }

    try {
      final result = await _functions.httpsCallable('resumeGameSession').call({
        'chapterIndex': chapterIndex,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        await SaveManager.setGameSessionId(_activeGameSessionId!);
        final returnedChapter = data['chapterIndex'];
        _activeGameChapterIndex = returnedChapter is num
            ? returnedChapter.toInt().clamp(0, 5)
            : chapterIndex;
        final lifeState = data['life'];
        if (lifeState is Map) {
          LifeManager.applyServerState(
            Map<String, dynamic>.from(lifeState),
          );
        } else {
          await LifeManager.refreshFromServer();
        }
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      // An expired server session cannot be resumed. At that point the local
      // board is stale relative to the server, so this entry must become a
      // fresh game and consume exactly one Life through startGameSession.
      // Do not apply this fallback to other resume failures: a normal
      // unfinished session must never be silently replaced.
      // ignore: avoid_print
      print(
        'resumeGameSession failed: code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details?.toString()},',
      );

      final isExpiredSession =
          error.code == 'deadline-exceeded' &&
          (error.message ?? '').toLowerCase().contains('expired');
      if (isExpiredSession) {
        await refresh();
        return startGameSession(
          chapterIndex,
          replaceActiveSession: true,
        );
      }
    }
    return false;
  }

  Future<bool> restartGameSession(
    int chapterIndex, {
    Map<String, dynamic>? replayLog,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    try {
      final result = await _functions.httpsCallable('restartGameSession').call({
        'chapterIndex': chapterIndex,
        if (_activeGameSessionId != null) 'sessionId': _activeGameSessionId,
        'replayLog': ?replayLog,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        _activeGameSessionId = data['sessionId'] as String;
        await SaveManager.setGameSessionId(
          _activeGameSessionId!,
          chapter: _chapterNames[chapterIndex],
        );
        _activeGameChapterIndex = chapterIndex;

        // restartGameSession already returns the life state from the same
        // Firestore transaction that consumed the Life. Apply that exact
        // state instead of issuing a second read that can race with the
        // transaction and restore a stale balance in the UI.
        final lifeState = <String, dynamic>{
          'lives': data['lives'],
          'infiniteLives': data['infiniteLives'],
          'membership': data['membership'],
          'lifeMode': data['lifeMode'],
          'nextLifeAtMillis': data['nextLifeAtMillis'],
        };
        if (lifeState['lives'] is int &&
            lifeState['infiniteLives'] is bool &&
            lifeState['membership'] is String &&
            lifeState['lifeMode'] is String) {
          LifeManager.applyServerState(lifeState);
        } else {
          await LifeManager.refreshFromServer();
        }
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

  Future<void> exitUnfinishedGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
  }) async {
    final settledSessionId = sessionId ?? _activeGameSessionId;
    if (settledSessionId == null) return;

    try {
      final result = await _functions.httpsCallable('abandonGameSession').call({
        'sessionId': settledSessionId,
        'unfinishedExit': true,
        'replayLog': ?replayLog,
      });
      final data = result.data;
      final lifeState = data is Map ? data['life'] : null;
      if (lifeState is Map) {
        LifeManager.applyServerState(
          Map<String, dynamic>.from(lifeState),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      // ignore: avoid_print
      print(
        'exitUnfinishedGameSession failed: code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details?.toString()},',
      );
      await refresh();
    }
  }

  Future<void> abandonGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
  }) async {
    final settledSessionId = sessionId ?? _activeGameSessionId;
    if (settledSessionId == null) return;

    try {
      final result =
          await _functions.httpsCallable('abandonGameSession').call({
        'sessionId': settledSessionId,
        'replayLog': ?replayLog,
      });

      if (_activeGameSessionId == settledSessionId) {
        _activeGameSessionId = null;
        _activeGameChapterIndex = null;
        await SaveManager.clearGameSessionId();
      }

      final data = result.data;
      final chapterProgress = data is Map ? data['chapterProgress'] : null;
      if (chapterProgress is Map) {
        for (final entry in chapterProgress.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final highest = value['highestValue'];
          final score = value['score'];
          if (highest is num && score is num) {
            _chapterProgress[entry.key.toString()] = {
              'highestValue': highest.toInt(),
              'score': score.toInt(),
            };
          }
        }
        _loadedFromServer = true;
      }
    } on FirebaseFunctionsException catch (error) {
      // Keep the server error visible during development. Do not clear the
      // local session when the server did not confirm abandonment.
      // ignore: avoid_print
      print(
        'abandonGameSession failed: code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details}',
      );
    }
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
        _activeGameSessionId = null;
        _activeGameChapterIndex = null;
        await SaveManager.clearGameSessionId();
        return true;
      }
    } on FirebaseFunctionsException {
      return false;
    }
    return false;
  }
}
