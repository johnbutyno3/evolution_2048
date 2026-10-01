import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/game_tile.dart';
import 'active_game_store.dart';
import 'game_engine.dart';
import 'life_manager.dart';

enum GameOpenResult {
  opened,
  noLife,
  otherChapterActive,
  rejected,
}

/// Single owner of the gameplay lifecycle.
///
/// GameEngine owns only board mechanics. This class owns the one ActiveGame,
/// Life consumption, Home/Abandon/GameOver transitions, and background server
/// verification.
class GameLifecycleManager {
  GameLifecycleManager._();

  static final instance = GameLifecycleManager._();
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _activeStatus = 'active';
  static const _gameOverStatus = 'game_over';
  static const _abandonedStatus = 'abandoned';
  static const _completedStatus = 'completed';

  Map<String, dynamic>? _active;
  bool _opening = false;
  final Map<String, Future<void>> _pendingStarts = <String, Future<void>>{};

  Map<String, dynamic>? get active => _active;
  String? get activeGameId => _active?['gameId'] as String?;
  int? get activeChapter => (_active?['chapterIndex'] as num?)?.toInt();
  bool get hasActiveGame => _active?['status'] == _activeStatus;

  Future<void> initialize() async {
    await ActiveGameStore.setAccountScope(_auth.currentUser?.uid);
    _active = await ActiveGameStore.load();
    if (_active?['status'] != _activeStatus) {
      _active = null;
    }
  }

  Future<(GameEngine?, GameOpenResult)> open({
    required GameChapter chapter,
  }) async {
    if (_opening) return (null, GameOpenResult.rejected);
    _opening = true;
    try {
      await initialize();

      final wanted = chapter.index;
      if (hasActiveGame) {
        if (activeChapter != wanted) {
          return (null, GameOpenResult.otherChapterActive);
        }

        final saved = Map<String, dynamic>.from(_active!);
        final engine = GameEngine(
          chapter: chapter,
          forceNewBoard: true,
          gameId: saved['gameId'] as String?,
        );
        if (!engine.restoreFromSaveData(saved)) {
          await abandonLocalOnly();
          return (null, GameOpenResult.rejected);
        }
        return (engine, GameOpenResult.opened);
      }

      if (!LifeManager.isGoldenMember &&
          LifeManager.lifeCount <= 0) {
        return (null, GameOpenResult.noLife);
      }

      if (!LifeManager.optimisticConsumeLife()) {
        return (null, GameOpenResult.noLife);
      }

      final gameId = _newGameId();
      final engine = GameEngine(
        chapter: chapter,
        forceNewBoard: true,
        gameId: gameId,
      );
      await save(engine);

      final startVerification = _verifyStart(
        gameId: gameId,
        chapterIndex: wanted,
        initialTiles: engine.board.tiles.map((tile) => tile?.value).toList(),
      );
      _pendingStarts[gameId] = startVerification;
      unawaited(startVerification.whenComplete(() {
        _pendingStarts.remove(gameId);
      }));

      return (engine, GameOpenResult.opened);
    } finally {
      _opening = false;
    }
  }

  Future<void> waitForPendingStarts() async {
    final pending = List<Future<void>>.from(_pendingStarts.values);
    if (pending.isEmpty) return;
    await Future.wait(pending);
  }

  Future<void> save(GameEngine engine) async {
    final data = engine.createSaveData();
    final gameId = engine.gameId;
    if (gameId == null || gameId.isEmpty) return;

    data['gameId'] = gameId;
    data['chapterIndex'] = engine.chapter.index;
    data['status'] = _activeStatus;
    data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    _active = Map<String, dynamic>.from(data);
    await ActiveGameStore.save(_active!);
  }

  Future<void> abandon(GameEngine engine) async {
    engine.pauseGameTimer();
    await save(engine);
    final gameId = engine.gameId;
    await _finishLocal(_abandonedStatus);
    if (gameId != null) {
      unawaited(_verifyFinish(gameId: gameId, reason: 'abandoned'));
    }
  }

  Future<(GameEngine?, GameOpenResult)> restart(GameEngine engine) async {
    final gameId = engine.gameId;
    if (gameId == null || gameId.isEmpty) {
      return (null, GameOpenResult.rejected);
    }

    engine.pauseGameTimer();
    await save(engine);
    await _finishLocal(_abandonedStatus);

    final finished = await _verifyFinish(
      gameId: gameId,
      reason: 'abandoned',
    );
    if (!finished) {
      return (null, GameOpenResult.rejected);
    }

    return open(chapter: engine.chapter);
  }

  Future<void> gameOver(GameEngine engine) async {
    await save(engine);
    final gameId = engine.gameId;
    await _finishLocal(_gameOverStatus);
    if (gameId != null) {
      unawaited(_verifyFinish(gameId: gameId, reason: 'game_over'));
    }
  }

  Future<void> complete(GameEngine engine) async {
    await save(engine);
    final gameId = engine.gameId;
    await _finishLocal(_completedStatus);
    if (gameId != null) {
      unawaited(_verifyFinish(
        gameId: gameId,
        reason: 'completed',
        chapterIndex: engine.chapter.index,
        highestValue: engine.highestValue,
        score: engine.score,
      ));
    }
  }

  Future<void> abandonLocalOnly() async {
    _active = null;
    await ActiveGameStore.clear();
  }

  Future<void> _finishLocal(String status) async {
    if (_active != null) {
      _active = Map<String, dynamic>.from(_active!);
      _active!['status'] = status;
      _active!['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    await ActiveGameStore.clear();
    _active = null;
  }

  Future<void> _verifyStart({
    required String gameId,
    required int chapterIndex,
    required List<int?> initialTiles,
  }) async {
    const hardRejectCodes = <String>{
      'invalid-argument',
      'unauthenticated',
      'permission-denied',
      'failed-precondition',
      'already-exists',
    };
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
    ];

    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      if (retryDelays[attempt] > Duration.zero) {
        await Future<void>.delayed(retryDelays[attempt]);
      }

      try {
        final result = await _functions.httpsCallable('beginGame').call({
          'gameId': gameId,
          'chapterIndex': chapterIndex,
          'initialTiles': initialTiles,
        });
        final data = Map<String, dynamic>.from(result.data as Map);
        if (data['gameId'] != gameId) {
          await _revokeRejectedStart();
          return;
        }
        if (_active?['gameId'] != gameId ||
            _active?['status'] != _activeStatus) {
          unawaited(_verifyFinish(gameId: gameId, reason: 'abandoned'));
          return;
        }
        if (data['lives'] is int) {
          LifeManager.applyServerState(data);
        }
        return;
      } on FirebaseFunctionsException catch (error) {
        if (hardRejectCodes.contains(error.code)) {
          await _revokeRejectedStart();
          return;
        }
        // Transient Firebase/network errors are retried. beginGame is
        // idempotent for the same gameId + chapter + initial board.
      } catch (_) {
        // Non-Firebase transport errors are also safe to retry.
      }
    }
    // All verification attempts failed transiently. Keep the local game
    // playable; a later authenticated lifecycle refresh can reconcile it.
  }

  Future<void> _revokeRejectedStart() async {
    await ActiveGameStore.clear();
    _active = null;
    await LifeManager.refreshFromServer().catchError((_) {});
  }

  Future<bool> _verifyFinish({
    required String gameId,
    required String reason,
    int? chapterIndex,
    int? highestValue,
    int? score,
  }) async {
    final pendingStart = _pendingStarts[gameId];
    if (pendingStart != null) {
      await pendingStart;
    }

    const retryDelays = <Duration>[
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
    ];

    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        await _functions.httpsCallable('finishGame').call({
          'gameId': gameId,
          'reason': reason,
          'chapterIndex': ?chapterIndex,
          'highestValue': ?highestValue,
          'score': ?score,
        });
        return true;
      } catch (_) {
        // finishGame is idempotent for an already-ended session. Retry
        // transient failures without blocking normal local transitions.
      }
    }
    return false;
  }

  String _newGameId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'g_$hex';
  }
}
