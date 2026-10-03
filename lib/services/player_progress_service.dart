// ignore_for_file: avoid_print

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../game/services/tool_manager.dart';
import 'session_generation.dart';

/// Server-verified account progression with local-first gameplay entry.
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
  Future<bool>? _pendingStartSession;
  int _sessionOperationGeneration = 0;
  final SessionGeneration _sessionIdentityGeneration = SessionGeneration();

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

    // Refresh is a reader of authoritative server state, not a session owner.
    // Capture the owner generation before the network await. RESET increments
    // this generation as soon as it begins, so a late refresh can finish but
    // can no longer publish its snapshot into the replacement session.
    final refreshGeneration = _sessionIdentityGeneration.current;
    final refreshOwnerSessionId = _activeGameSessionId;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(_progressCollection)
          .doc(_progressDocument)
          .get(const GetOptions(source: Source.server));

      if (!_sessionIdentityGeneration.isCurrent(refreshGeneration) ||
          _activeGameSessionId != refreshOwnerSessionId) {
        return;
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final value = data['unlockedChapterIndex'];
      final unlockedChapterIndex =
          value is num ? value.toInt().clamp(0, 5) : 0;

      final refreshedChapterProgress = <String, Map<String, int>>{};
      final chapterProgress = data['chapterProgress'];
      if (chapterProgress is Map) {
        for (final entry in chapterProgress.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final highest = value['highestValue'];
          final score = value['score'];
          refreshedChapterProgress[entry.key.toString()] = {
            'highestValue': highest is num ? highest.toInt() : 0,
            'score': score is num ? score.toInt() : 0,
          };
        }
      }

      final sessionId = data['activeGameSessionId'];
      final refreshedSessionId =
          sessionId is String && sessionId.isNotEmpty ? sessionId : null;

      final activeChapter = data['activeGameChapterIndex'];
      final refreshedChapterIndex = activeChapter is num
          ? activeChapter.toInt().clamp(0, 5)
          : null;

      // The session generation is still checked immediately before the local
      // identity commit. This closes the window between parsing the response
      // and publishing the server session to the local state.
      if (!_sessionIdentityGeneration.isCurrent(refreshGeneration) ||
          _activeGameSessionId != refreshOwnerSessionId) {
        return;
      }

      _unlockedChapterIndex = unlockedChapterIndex;
      _chapterProgress
        ..clear()
        ..addAll(refreshedChapterProgress);
      _activeGameSessionId = refreshedSessionId;
      _activeGameChapterIndex = refreshedChapterIndex;

      // The queue itself is guarded as well. RESET can begin after the
      // in-memory commit above but before SharedPreferences executes this
      // write; queue-time ownership prevents that stale refresh from writing
      // the old session ID into SaveManager.
      if (refreshedSessionId == null) {
        await SaveManager.clearGameSessionIdIf(() =>
            _sessionIdentityGeneration.isCurrent(refreshGeneration) &&
            _activeGameSessionId == refreshedSessionId);
      } else if (SaveManager.gameSessionId != refreshedSessionId) {
        await SaveManager.setGameSessionIdIf(
          refreshedSessionId,
          () =>
              _sessionIdentityGeneration.isCurrent(refreshGeneration) &&
              _activeGameSessionId == refreshedSessionId,
        );
      }

      if (!_sessionIdentityGeneration.isCurrent(refreshGeneration) ||
          _activeGameSessionId != refreshedSessionId) {
        return;
      }

      _loadedFromServer = true;
    } on FirebaseException {
      if (_sessionIdentityGeneration.isCurrent(refreshGeneration) &&
          _activeGameSessionId == refreshOwnerSessionId) {
        _loadedFromServer = false;
      }
    }
  }

  /// Starts the game locally first. The server still creates and validates the
  /// charged session in the background; its authoritative response replaces
  /// the optimistic Life state as soon as it arrives.
  Future<bool> startGameSession(
    int chapterIndex, {
    bool replaceActiveSession = false,
    bool retryAfterPendingFailure = false,
    required List<dynamic> initialTiles,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    // A second normal start while the first local-first start is still
    // being verified is already covered by that first operation. Return
    // immediately so duplicate UI calls never wait on Firebase and never
    // create another charged session. Completion recovery is the one
    // intentional exception: it must wait for the failed start before retrying.
    final pendingStart = _pendingStartSession;
    if (pendingStart != null) {
      if (!retryAfterPendingFailure) return true;
      final pendingResult = await pendingStart;
      if (pendingResult) return true;
    }

    // Do not let a known-empty local/server snapshot start a game. For a
    // normal positive balance, decrement locally so board creation is not
    // blocked by network latency.
    if (!LifeManager.optimisticConsumeLife()) return false;

    final operationGeneration = ++_sessionOperationGeneration;
    final pending = _startGameSessionOnServer(
      chapterIndex,
      replaceActiveSession: replaceActiveSession,
      initialTiles: initialTiles,
      operationGeneration: operationGeneration,
    );
    _pendingStartSession = pending;
    unawaited(pending.whenComplete(() {
      if (identical(_pendingStartSession, pending)) {
        _pendingStartSession = null;
      }
    }));

    return true;
  }

  Future<bool> _startGameSessionOnServer(
    int chapterIndex, {
    required bool replaceActiveSession,
    required List<dynamic> initialTiles,
    required int operationGeneration,
  }) async {
    final previousSessionId = _activeGameSessionId;
    try {
      final result = await _functions.httpsCallable('startGameSession').call({
        'chapterIndex': chapterIndex,
        'replaceActiveSession': replaceActiveSession,
        'initialTiles': initialTiles,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        if (operationGeneration != _sessionOperationGeneration) return false;
        _activeGameSessionId = data['sessionId'] as String;
        // Restart creates a replacement board locally. Do not rebind the old
        // cached board to the new session: that would resurrect the previous
        // board when the player re-enters. The new GameEngine snapshot is
        // persisted separately by the caller after this session is accepted.
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
      print(
        'startGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (operationGeneration == _sessionOperationGeneration) {
        await refresh();
        if (operationGeneration != _sessionOperationGeneration) return false;
        final serverSessionId = _activeGameSessionId;
        final startCommitted =
            serverSessionId != null &&
            serverSessionId != previousSessionId &&
            _activeGameChapterIndex == chapterIndex;
        await LifeManager.refreshFromServer();
        if (startCommitted) {
          await SaveManager.setGameSessionId(serverSessionId);
          return true;
        }
      }
    } catch (error) {
      print('startGameSession verification failed: $error');
      try {
        if (operationGeneration == _sessionOperationGeneration) {
          await refresh();
          if (operationGeneration != _sessionOperationGeneration) return false;
          final serverSessionId = _activeGameSessionId;
          final startCommitted =
              serverSessionId != null &&
              serverSessionId != previousSessionId &&
              _activeGameChapterIndex == chapterIndex;
          await LifeManager.refreshFromServer();
          if (startCommitted) {
            await SaveManager.setGameSessionId(serverSessionId);
            return true;
          }
        }
      } catch (_) {
        // Keep the optimistic UI responsive; the next authoritative refresh
        // will reconcile the balance.
      }
    }
    return false;
  }

  Future<bool> _awaitPendingStartSession() async {
    final pending = _pendingStartSession;
    if (pending == null) return _activeGameSessionId != null;
    return pending;
  }

  /// Re-enters the server-owned unfinished session.
  Future<bool> resumeGameSession(
    int chapterIndex, {
    String? sessionId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    final chapterName = _chapterNames[chapterIndex];
    final bindingSessionId = sessionId ?? _activeGameSessionId;
    final saved = SaveManager.loadCached(chapter: chapterName);
    final hasPlayableLocalBoard = saved != null &&
        saved['gameSessionId'] == bindingSessionId &&
        saved['gameOver'] != true &&
        saved['chapterComplete'] != true &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == 16;

    if (!hasPlayableLocalBoard) return false;

    final operationGeneration = ++_sessionOperationGeneration;
    try {
      final result = await _functions.httpsCallable('resumeGameSession').call({
        'chapterIndex': chapterIndex,
        'sessionId': ?sessionId,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        if (operationGeneration != _sessionOperationGeneration) return false;
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
        return false;
      }
    }
    return false;
  }

  Future<bool> restartGameSession(
    int chapterIndex, {
    Map<String, dynamic>? replayLog,
    String? replaySessionId,
    required List<dynamic> initialTiles,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    // RESET takes ownership immediately. This invalidates any refresh that is
    // already waiting on Firestore before the replacement session is created.
    _sessionIdentityGeneration.begin();

    final pendingStart = _pendingStartSession;
    if (pendingStart != null) {
      await pendingStart;
    }

    final operationGeneration = ++_sessionOperationGeneration;
    final previousSessionId = _activeGameSessionId;
    try {
      final result = await _functions.httpsCallable('restartGameSession').call({
        'chapterIndex': chapterIndex,
        'replaySessionId': ?replaySessionId,
        'replayLog': ?replayLog,
        'initialTiles': initialTiles,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        if (operationGeneration != _sessionOperationGeneration) return false;

        _activeGameSessionId = data['sessionId'] as String;
        await SaveManager.setGameSessionId(_activeGameSessionId!);
        _activeGameChapterIndex = chapterIndex;

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

        await ToolManager.refreshInventory();
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      print(
        'restartGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (operationGeneration == _sessionOperationGeneration) {
        await refresh();
        if (operationGeneration != _sessionOperationGeneration) return false;
        final refreshedSessionId = _activeGameSessionId;
        final restartCommitted =
            refreshedSessionId != null &&
            refreshedSessionId != previousSessionId &&
            _activeGameChapterIndex == chapterIndex;
        await LifeManager.refreshFromServer();
        if (restartCommitted) {
          await SaveManager.setGameSessionId(refreshedSessionId);
          await ToolManager.refreshInventory();
          return true;
        }
      }
    }
    return false;
  }

  Future<void> abandonGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
    bool unfinishedExit = false,
  }) async {
    final requestedSessionId = sessionId ?? _activeGameSessionId;
    if (requestedSessionId != null &&
        _activeGameSessionId == requestedSessionId) {
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      if (!unfinishedExit) {
        unawaited(SaveManager.clearGameSessionId());
      }
    }

    await _awaitPendingStartSession();
    final settledSessionId = sessionId ?? _activeGameSessionId;
    if (settledSessionId == null) return;

    if (_activeGameSessionId == settledSessionId) {
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      if (!unfinishedExit) {
        unawaited(SaveManager.clearGameSessionId());
      }
    }

    try {
      final result = await _functions.httpsCallable('abandonGameSession').call({
        'sessionId': settledSessionId,
        'replayLog': ?replayLog,
        'unfinishedExit': unfinishedExit,
      });

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
      print(
        'abandonGameSession failed: code='
        '${error.code}, message=${error.message}, '
        'details=${error.details}',
      );
      unawaited(refresh());
    }
  }

  Future<bool> completeChapter({
    required int chapterIndex,
    required Map<String, dynamic> replayLog,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    if (!await _awaitPendingStartSession()) {
      final initialTiles = replayLog['initialTiles'];
      if (initialTiles is! List || initialTiles.length != 16) return false;
      final recovered = await startGameSession(
        chapterIndex,
        initialTiles: List<dynamic>.from(initialTiles),
        retryAfterPendingFailure: true,
      );
      if (!recovered) return false;
    }
    final sessionId = _activeGameSessionId;
    if (sessionId == null) return false;

    final operationGeneration = ++_sessionOperationGeneration;
    try {
      final result = await _functions.httpsCallable('completeChapter').call({
        'sessionId': sessionId,
        'chapterIndex': chapterIndex,
        'replayLog': replayLog,
      });
      final data = result.data;
      if (data is Map && data['unlockedChapterIndex'] is num) {
        if (operationGeneration != _sessionOperationGeneration) return false;
        _unlockedChapterIndex =
            (data['unlockedChapterIndex'] as num).toInt().clamp(0, 5);
        _loadedFromServer = true;
        _activeGameSessionId = null;
        _activeGameChapterIndex = null;
        await SaveManager.clearGameSessionId();
        await ToolManager.refreshInventory();
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      print(
        'completeChapter failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (operationGeneration == _sessionOperationGeneration) {
        await refresh();
        if (operationGeneration != _sessionOperationGeneration) return false;

        final sessionClosed =
            _activeGameSessionId == null &&
            _activeGameChapterIndex == null;
        final chapterTargetReached =
            chapterHighestValue(chapterIndex) >= (1 << (chapterIndex + 12));
        final completionCommitted = sessionClosed && chapterTargetReached;

        if (completionCommitted) {
          await SaveManager.clearGameSessionId();
          await ToolManager.refreshInventory();
          return true;
        }
      }
    } catch (error) {
      print('completeChapter verification failed: $error');
      if (operationGeneration == _sessionOperationGeneration) {
        try {
          await refresh();
          if (operationGeneration != _sessionOperationGeneration) return false;
          final sessionClosed =
              _activeGameSessionId == null &&
              _activeGameChapterIndex == null;
          final chapterTargetReached =
              chapterHighestValue(chapterIndex) >= (1 << (chapterIndex + 12));
          if (sessionClosed && chapterTargetReached) {
            await SaveManager.clearGameSessionId();
            await ToolManager.refreshInventory();
            return true;
          }
        } catch (_) {
          // Keep the local completion state unchanged until the next
          // authoritative refresh can reconcile it.
        }
      }
    }
    return false;
  }
}
