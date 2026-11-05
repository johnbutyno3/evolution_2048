// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../game/services/tool_manager.dart';
import 'session_generation.dart';
import 'supabase_account_service.dart';
import 'supabase_backend.dart';
import 'supabase_game_session_service.dart';

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

  static final Random _uuidRandom = Random.secure();
  static String _newUuid() {
    final bytes = List<int>.generate(16, (_) => _uuidRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
  }
  static List<int?> _initialBoard(List<dynamic> values) {
    if (values.length != 16) throw ArgumentError.value(values.length, 'initialTiles.length');
    return values.map<int?>((value) {
      if (value == null || value == 0) return null;
      if (value is num && (value == 2 || value == 4)) return value.toInt();
      throw ArgumentError.value(value, 'initialTiles');
    }).toList(growable: false);
  }
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
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      _unlockedChapterIndex = 0;
      _loadedFromServer = false;
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      _chapterProgress.clear();
      return;
    }
    final generation = _sessionIdentityGeneration.current;
    final owner = _activeGameSessionId;
    try {
      final snapshot = await SupabaseAccountService.fetchSnapshot();
      if (!_sessionIdentityGeneration.isCurrent(generation) ||
          _activeGameSessionId != owner || snapshot.userId != user.id) return;
      var unlocked = 0;
      for (final entry in snapshot.chapterProgress.entries) {
        final chapter = int.tryParse(entry.key.replaceFirst('C', ''));
        if (chapter == null) continue;
        if ((entry.value['highestStage'] ?? 0) >= chapter + 11) {
          unlocked = chapter.clamp(1, 5);
        }
      }
      final activeId = snapshot.activeGameId;
      final activeChapter = snapshot.activeChapterCode == null
          ? null
          : int.tryParse(snapshot.activeChapterCode!.replaceFirst('C', ''))! - 1;
      _unlockedChapterIndex = unlocked;
      _chapterProgress
        ..clear()
        ..addAll(snapshot.legacyChapterProgress);
      _activeGameSessionId = activeId;
      _activeGameChapterIndex = activeChapter;
      if (activeId == null) {
        await SaveManager.clearGameSessionIdIf(() =>
            _sessionIdentityGeneration.isCurrent(generation) &&
            _activeGameSessionId == null);
      } else {
        await SaveManager.setGameSessionIdIf(activeId, () =>
            _sessionIdentityGeneration.isCurrent(generation) &&
            _activeGameSessionId == activeId);
      }
      if (_sessionIdentityGeneration.isCurrent(generation) &&
          _activeGameSessionId == activeId) _loadedFromServer = true;
    } on SupabaseAccountException {
      if (_sessionIdentityGeneration.isCurrent(generation) &&
          _activeGameSessionId == owner) _loadedFromServer = false;
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
    final gameId = _newUuid();
    try {
      final result = await SupabaseGameSessionService.startGameSession(
        requestId: _newUuid(),
        gameId: gameId,
        chapterCode: 'C${chapterIndex + 1}',
        previousGameId: replaceActiveSession ? previousSessionId : null,
        initialTiles: _initialBoard(initialTiles),
      );
      if (operationGeneration != _sessionOperationGeneration ||
          result['gameId'] != gameId || result['state'] != 'ACTIVE') return false;
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      await SaveManager.setGameSessionId(gameId);
      await refresh();
      return _activeGameSessionId == gameId;
    } catch (_) {
      if (operationGeneration != _sessionOperationGeneration) return false;
      await refresh();
      final committed = _activeGameSessionId == gameId &&
          _activeGameChapterIndex == chapterIndex;
      if (!committed) await LifeManager.refreshFromServer();
      return committed;
    }
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
    if (SupabaseBackend.client.auth.currentUser == null ||
        chapterIndex < 0 || chapterIndex > 5) return false;
    final gameId = sessionId ?? _activeGameSessionId;
    if (gameId == null) return false;
    final saved = SaveManager.loadCached(chapter: _chapterNames[chapterIndex]);
    final playable = saved != null &&
        saved['gameSessionId'] == gameId &&
        saved['gameOver'] != true &&
        saved['chapterComplete'] != true &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == 16;
    if (!playable) return false;
    final generation = ++_sessionOperationGeneration;
    try {
      final result = await SupabaseGameSessionService.resumeGameSession(gameId: gameId);
      if (generation != _sessionOperationGeneration ||
          result['gameId'] != gameId ||
          result['chapterCode'] != 'C${chapterIndex + 1}' ||
          result['state'] != 'ACTIVE') return false;
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      await SaveManager.setGameSessionId(gameId);
      await refresh();
      return _activeGameSessionId == gameId;
    } catch (_) {
      if (generation == _sessionOperationGeneration) await refresh();
      return false;
    }
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
        // Bind this reset to the session it is replacing. If two reset
        // requests race, only the first can replace/charge that session.
        // A lost response is recovered by refresh() below, not by charging
        // another replacement session.
        'sessionId': ?previousSessionId,
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

