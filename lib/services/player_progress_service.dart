// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math';


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

  static const List<String> _chapterNames = <String>[
    'ocean',
    'land',
    'sky',
    'history',
    'tech',
    'universe',
  ];


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
  String? _activeGameRequestId;
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
    // A cached chapter index is not proof of current account access. If the
    // authoritative snapshot failed (or belongs to a previous account), keep
    // every chapter locked until the server progress has been refreshed.
    return _loadedFromServer &&
        chapterIndex >= 0 &&
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
      _activeGameRequestId = null;
      _activeGameChapterIndex = null;
      _chapterProgress.clear();
      return;
    }
    final generation = _sessionIdentityGeneration.current;
    final owner = _activeGameSessionId;
    try {
      final snapshot = await SupabaseAccountService.fetchSnapshot();
      if (!_sessionIdentityGeneration.isCurrent(generation) ||
          _activeGameSessionId != owner || snapshot.userId != user.id) {
        return;
      }
      var unlocked = 0;
      for (final entry in snapshot.chapterProgress.entries) {
        final chapter = int.tryParse(entry.key.replaceFirst('C', ''));
        if (chapter == null) continue;
        if ((entry.value['highestStage'] ?? 0) >= chapter + 11) {
          unlocked = chapter.clamp(1, 5).toInt();
        }
      }
      final activeId = snapshot.activeGameId;
      _activeGameRequestId = snapshot.activeGameRequestId;
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
          _activeGameSessionId == activeId) {
        _loadedFromServer = true;
      }
    } on SupabaseAccountException {
      if (_sessionIdentityGeneration.isCurrent(generation) &&
          _activeGameSessionId == owner) {
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
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null || chapterIndex < 0 || chapterIndex > 5) return false;

    // A second normal start while the first local-first start is still
    // being verified is already covered by that first operation. Return
    // immediately so duplicate UI calls never wait on Supabase and never
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
          result['gameId'] != gameId || result['state'] != 'ACTIVE') {
        return false;
      }
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      await SaveManager.setGameSessionId(gameId);
      await refresh();
      await LifeManager.refreshFromServer();
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
        chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }
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
          result['state'] != 'ACTIVE') {
        return false;
      }
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
    if (SupabaseBackend.client.auth.currentUser == null ||
        chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }

    _sessionIdentityGeneration.begin();
    final pending = _pendingStartSession;
    if (pending != null) await pending;
    final generation = ++_sessionOperationGeneration;
    final previousGameId = _activeGameSessionId ?? replaySessionId;
    final requestId = _newUuid();
    final gameId = _newUuid();

    try {
      final tiles = _initialBoard(initialTiles);
      final Map<String, dynamic> result;
      if (previousGameId == null) {
        result = await SupabaseGameSessionService.startGameSession(
          requestId: requestId,
          gameId: gameId,
          chapterCode: 'C${chapterIndex + 1}',
          initialTiles: tiles,
        );
      } else {
        if (replayLog == null) return false;
        result = await SupabaseGameSessionService.restartGameSession(
          requestId: requestId,
          gameId: gameId,
          previousGameId: previousGameId,
          eventId: _newUuid(),
          chapterCode: 'C${chapterIndex + 1}',
          initialTiles: tiles,
          replayLog: replayLog,
        );
      }
      if (generation != _sessionOperationGeneration ||
          result['gameId'] != gameId || result['requestId'] != requestId || result['state'] != 'ACTIVE') {
        return false;
      }
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      await SaveManager.setGameSessionId(gameId);
      await refresh();
      await LifeManager.refreshFromServer();
      await ToolManager.refreshInventory();
      return _activeGameSessionId == gameId;
    } catch (_) {
      if (generation == _sessionOperationGeneration) {
        // The request may have committed on the server even when its response
        // was lost. Reconcile against the authoritative active-session pointer
        // before restoring the old local board or undoing the optimistic Life.
        await refresh();
        await LifeManager.refreshFromServer();
        final committedGameId = _activeGameSessionId;
        final committed = _activeGameChapterIndex == chapterIndex &&
            committedGameId != null &&
            _activeGameRequestId == requestId &&
            (committedGameId == gameId || committedGameId != previousGameId);
        if (committed) {
          // The atomic restart may have committed with a different generated
          // game ID before the response was lost. Match its server-stored
          // request ID before binding the local board to that session.
          await SaveManager.setGameSessionId(committedGameId);
          await ToolManager.refreshInventory();
          return true;
        }
      }
      return false;
    }
  }

  Future<bool> abandonGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
    String reason = 'PLAYER_ABANDONED',
    bool unfinishedExit = false,
  }) async {
    // Returning home preserves the active session so the player can resume it.
    if (unfinishedExit) return true;
    final gameId = sessionId ?? _activeGameSessionId;
    if (gameId == null) return true;
    if (replayLog == null) return false;
    await _awaitPendingStartSession();
    if (_activeGameSessionId != gameId) {
      return _loadedFromServer && _activeGameSessionId == null;
    }

    final generation = ++_sessionOperationGeneration;
    try {
      await SupabaseGameSessionService.abandonGameSession(
        gameId: gameId,
        eventId: _newUuid(),
        reason: reason,
        replayLog: replayLog,
      );
      if (generation != _sessionOperationGeneration) return false;
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      await SaveManager.clearGameSessionId();
      await refresh();
      if (!_loadedFromServer || _activeGameSessionId == gameId) return false;
      await ToolManager.refreshInventory();
      return true;
    } catch (_) {
      if (generation != _sessionOperationGeneration) return false;
      await refresh();
      // A lost response is successful only when a fresh authoritative
      // snapshot confirms that the server no longer owns this active session.
      if (_loadedFromServer && _activeGameSessionId != gameId) {
        await SaveManager.clearGameSessionId();
        await ToolManager.refreshInventory();
        return true;
      }
      return false;
    }
  }

  Future<bool> completeChapter({
    required int chapterIndex,
    required Map<String, dynamic> replayLog,
  }) async {
    if (SupabaseBackend.client.auth.currentUser == null ||
        chapterIndex < 0 || chapterIndex > 5) {
      return false;
    }
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
    final gameId = _activeGameSessionId;
    if (gameId == null || _activeGameChapterIndex != chapterIndex) return false;
    final generation = ++_sessionOperationGeneration;
    try {
      final result = await SupabaseGameSessionService.finishChapter(
        gameId: gameId,
        eventId: _newUuid(),
        replayLog: replayLog,
      );
      if (generation != _sessionOperationGeneration ||
          result['gameId'] != gameId || result['state'] != 'COMPLETED') {
        return false;
      }
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      await SaveManager.clearGameSessionId();
      await refresh();
      await LifeManager.refreshFromServer();
      await ToolManager.refreshInventory();
      return _activeGameSessionId == null &&
          chapterHighestValue(chapterIndex) >= (1 << (chapterIndex + 12));
    } catch (_) {
      if (generation != _sessionOperationGeneration) return false;
      await refresh();
      final completed = _activeGameSessionId == null &&
          chapterHighestValue(chapterIndex) >= (1 << (chapterIndex + 12));
      if (completed) {
        await SaveManager.clearGameSessionId();
        await ToolManager.refreshInventory();
      }
      return completed;
    }
  }

}

