import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

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
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _activeStatus = 'active';
  static const _gameOverStatus = 'game_over';
  static const _abandonedStatus = 'abandoned';
  static const _completedStatus = 'completed';

  Map<String, dynamic>? _active;
  bool _opening = false;

  Map<String, dynamic>? get active => _active;
  String? get activeGameId => _active?['gameId'] as String?;
  int? get activeChapter => (_active?['chapterIndex'] as num?)?.toInt();
  bool get hasActiveGame => _active?['status'] == _activeStatus;

  Future<void> initialize() async {
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
          boardLifeActive: true,
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
        boardLifeActive: true,
        gameId: gameId,
      );
      await save(engine);

      unawaited(_verifyStart(
        gameId: gameId,
        chapterIndex: wanted,
        initialTiles: engine.board.tiles.map((tile) => tile?.value).toList(),
      ));

      return (engine, GameOpenResult.opened);
    } finally {
      _opening = false;
    }
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

  Future<void> gameOver(GameEngine engine) async {
    await engine.flushLocalSave();
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
      if (data['lives'] is int) {
        LifeManager.applyServerState(data);
      }
    } on FirebaseFunctionsException {
      await _revokeRejectedStart();
    } catch (_) {
      // A temporary network failure does not interrupt local gameplay.
    }
  }

  Future<void> _revokeRejectedStart() async {
    await ActiveGameStore.clear();
    _active = null;
    await LifeManager.refreshFromServer().catchError((_) {});
  }

  Future<void> _verifyFinish({
    required String gameId,
    required String reason,
    int? chapterIndex,
    int? highestValue,
    int? score,
  }) async {
    try {
      await _functions.httpsCallable('finishGame').call({
        'gameId': gameId,
        'reason': reason,
        if (chapterIndex != null) 'chapterIndex': chapterIndex,
        if (highestValue != null) 'highestValue': highestValue,
        if (score != null) 'score': score,
      });
    } catch (_) {
      // The local state is already settled. The next authenticated refresh
      // is responsible for reconciliation.
    }
  }

  String _newGameId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'g_$hex';
  }
}
