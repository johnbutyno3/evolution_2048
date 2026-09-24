import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../game/services/tool_manager.dart';

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

      // Keep the local session pointer aligned with the authoritative server
      // state. In particular, an abandon/game-over transaction can commit
      // successfully while its callable response is lost; leaving the old
      // local ID behind would make the next local-first start look as if it
      // were replacing/resuming a session that no longer exists.
      if (_activeGameSessionId == null) {
        await SaveManager.clearGameSessionId();
      } else if (SaveManager.gameSessionId != _activeGameSessionId) {
        await SaveManager.setGameSessionId(_activeGameSessionId!);
      }

      _loadedFromServer = true;
    } on FirebaseException {
      _loadedFromServer = false;
    }
  }

  /// Starts the game locally first. The server still creates and validates the
  /// charged session in the background; its authoritative response replaces
  /// the optimistic Life state as soon as it arrives.
  Future<bool> startGameSession(
    int chapterIndex, {
    bool replaceActiveSession = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    // Do not let a known-empty local/server snapshot start a game. For a
    // normal positive balance, decrement locally so board creation is not
    // blocked by network latency.
    if (!LifeManager.optimisticConsumeLife()) return false;

    final operationGeneration = ++_sessionOperationGeneration;
    final previousSessionId = _activeGameSessionId ?? SaveManager.gameSessionId;
    final pending = _startGameSessionOnServer(
      chapterIndex,
      replaceActiveSession: replaceActiveSession,
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
    required int operationGeneration,
  }) async {
    final previousSessionId = _activeGameSessionId ?? SaveManager.gameSessionId;
    try {
      final result = await _functions.httpsCallable('startGameSession').call({
        'chapterIndex': chapterIndex,
        'replaceActiveSession': replaceActiveSession,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        if (operationGeneration != _sessionOperationGeneration) return false;
        final previousSessionId =
            _activeGameSessionId ?? SaveManager.gameSessionId;
        _activeGameSessionId = data['sessionId'] as String;
        await SaveManager.rebindCachedGameSession(
          chapter: _chapterNames[chapterIndex],
          previousSessionId: previousSessionId,
          newSessionId: _activeGameSessionId!,
        );
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
      // The server remains authoritative. Expected failures such as no Life
      // simply reconcile the local optimistic state; security failures remain
      // visible to the backend enforcement layer.
      // ignore: avoid_print
      print(
        'startGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (operationGeneration == _sessionOperationGeneration) {
        // The callable can time out after the transaction has already created
        // the charged session. Refresh first so a lost response cannot make
        // the local-first client believe that the new game never started.
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
      // A network/client failure must never become a permanent local grant.
      // Reconcile with the server when connectivity is available again.
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
      return startGameSession(
        chapterIndex,
        replaceActiveSession: true,
      );
    }

    // Resume is a session-binding operation too. Give it a new generation
    // so a concurrent Restart/Start cannot later be overwritten by this
    // older Firebase response.
    final operationGeneration = ++_sessionOperationGeneration;
    try {
      final result = await _functions.httpsCallable('resumeGameSession').call({
        'chapterIndex': chapterIndex,
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

    final operationGeneration = ++_sessionOperationGeneration;
    final previousSessionId = _activeGameSessionId;
    try {
      final result = await _functions.httpsCallable('restartGameSession').call({
        'chapterIndex': chapterIndex,
        if (_activeGameSessionId != null) 'sessionId': _activeGameSessionId,
        'replayLog': ?replayLog,
      });
      final data = result.data;
      if (data is Map && data['sessionId'] is String) {
        // A newer session operation may have superseded this restart while
        // Firebase was processing it. Never let the stale response overwrite
        // the newer client session binding.
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

        // Restart creates a new GameEngine before this server call returns so
        // the replacement board stays responsive. Reconcile the authoritative
        // tool inventory now that the new session exists, then update the
        // already-mounted engine's ToolState as well. Without this second
        // step, the static inventory cache could be correct while the visible
        // tool button kept the old 0-use state from engine construction.
        await ToolManager.refreshInventory();
        return true;
      }
    } on FirebaseFunctionsException catch (error) {
      print(
        'restartGameSession failed: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      if (operationGeneration == _sessionOperationGeneration) {
        // A callable can time out after the Firestore transaction has already
        // committed. Refresh the authoritative progress before rolling back
        // the locally responsive replacement board. If the server session ID
        // changed, the restart succeeded and its response was merely lost.
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

  Future<void> exitUnfinishedGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
  }) async {
    await _awaitPendingStartSession();
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
      if (data is Map && data['status'] == 'ended') {
        if (_activeGameSessionId == settledSessionId) {
          _activeGameSessionId = null;
          _activeGameChapterIndex = null;
        }
      }
    } on FirebaseFunctionsException catch (error) {
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
    await _awaitPendingStartSession();
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
    if (user == null) return false;

    // A player can finish very quickly while the background session request
    // is still in flight. Wait only at completion time; normal board entry is
    // never blocked by Firebase latency.
    if (!await _awaitPendingStartSession()) return false;
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
      // completeChapter is transactional. Its Firestore writes may commit
      // even when the callable response is lost. Reconcile before declaring
      // the chapter completion failed, otherwise the client can remain on a
      // completed board while the server has already advanced progression.
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
        final completionCommitted =
            sessionClosed && chapterTargetReached;

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
