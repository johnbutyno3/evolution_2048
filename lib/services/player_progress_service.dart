import 'dart:math';

import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/save_manager.dart';
import '../game/services/tool_manager.dart';

enum RestartGameSessionResult {
  committed,
  rejected,
  pending,
}

/// Local-only chapter progression and game-session lifecycle.
/// There is no account, server session, or network dependency in this service.
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
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static List<int?> _initialBoard(List<dynamic> values) {
    if (values.length != 16) {
      throw ArgumentError.value(values.length, 'initialTiles.length');
    }
    return values.map<int?>((value) {
      if (value == null || value == 0) return null;
      if (value is num && (value == 2 || value == 4)) return value.toInt();
      throw ArgumentError.value(value, 'initialTiles');
    }).toList(growable: false);
  }

  int _unlockedChapterIndex = 0;
  final Map<String, Map<String, int>> _chapterProgress = <String, Map<String, int>>{};
  bool _loadedLocally = false;
  String? _activeGameSessionId;
  int? _activeGameChapterIndex;

  int get unlockedChapterIndex =>
      LifeManager.hasPermanentUnlock ? 5 : _unlockedChapterIndex;

  int chapterHighestValue(int chapterIndex) =>
      _chapterProgress[_chapterNames[chapterIndex]]?['highestValue'] ?? 0;

  int chapterScore(int chapterIndex) =>
      _chapterProgress[_chapterNames[chapterIndex]]?['score'] ?? 0;

  bool get loadedLocally => _loadedLocally;
  String? get activeGameSessionId => _activeGameSessionId;
  int? get activeGameChapterIndex => _activeGameChapterIndex;
  bool get hasUnfinishedGame => _activeGameSessionId != null;

  bool isChapterUnlocked(int chapterIndex) {
    if (!_loadedLocally || chapterIndex < 0 || chapterIndex > 5) return false;
    if (LifeManager.hasPermanentUnlock) return true;
    return chapterIndex == 0 &&
        !isChapterBlockedByUnfinishedGame(chapterIndex);
  }

  bool isChapterBlockedByUnfinishedGame(int chapterIndex) {
    final activeChapter = _activeGameChapterIndex;
    return activeChapter != null && activeChapter != chapterIndex;
  }

  /// Restores the local save pointer, including terminal boards awaiting
  /// completion/Game Over settlement after an interrupted app shutdown.
  Future<void> refresh() async {
    await LifeManager.initializeLocal();
    await GoldManager.refresh();
    var gameId = SaveManager.gameSessionId;
    var saved = SaveManager.loadCached();
    final savedChapter = saved?['chapter'];
    final savedGameId = saved?['gameSessionId'];
    final chapterIndex = savedChapter is String
        ? _chapterNames.indexOf(savedChapter)
        : -1;

    // Recover terminal sessions idempotently. A process can be killed after
    // the board becomes Game Over / Chapter Complete but before the session
    // pointer is cleared. Leaving that pointer active would trap Home on a
    // dead board and prevent the next legitimate new game.
    if (gameId != null &&
        savedGameId == gameId &&
        chapterIndex >= 0 &&
        chapterIndex <= 5 &&
        (saved?['gameOver'] == true || saved?['chapterComplete'] == true)) {
      final score = (saved?['score'] is num
              ? (saved!['score'] as num).toInt()
              : 0)
          .clamp(0, 1 << 30)
          .toInt();
      final speciesCount = saved?['speciesMergedThisGame'] is List
          ? (saved!['speciesMergedThisGame'] as List)
              .whereType<num>()
              .toSet()
              .length
          : 0;
      final highest = saved?['highestEvolutionValue'] is num
          ? (saved!['highestEvolutionValue'] as num).toInt()
          : 0;

      await GoldManager.settleGame(
        gameId: gameId,
        effectiveScore: score,
        newSpeciesCount: speciesCount,
        highestValue: highest,
      );

      if (saved?['chapterComplete'] == true) {
        await SaveManager.saveLocalChapterCompletion(
          chapterIndex: chapterIndex,
          score: score,
        );
        await GoldManager.awardChapterCompletion(chapterIndex);
        final completed = SaveManager.localChapterProgress.keys.toSet();
        if (List<String>.generate(6, (index) => 'C${index + 1}')
            .every(completed.contains)) {
          await GoldManager.awardAllChaptersCompletion();
        }
      }

      await SaveManager.clearGameSessionId();
      await SaveManager.clearChapter(_chapterNames[chapterIndex]);
      gameId = null;
      saved = null;
    }

    _chapterProgress
      ..clear()
      ..addAll(SaveManager.localChapterProgress);

    _unlockedChapterIndex = LifeManager.hasPermanentUnlock ? 5 : 0;

    if (gameId != null &&
        savedGameId == gameId &&
        chapterIndex >= 0 &&
        chapterIndex <= 5) {
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
    } else {
      final unfinished = SaveManager.unfinishedChapter;
      _activeGameSessionId =
          unfinished == null ? null : SaveManager.gameSessionId;
      _activeGameChapterIndex =
          unfinished == null ? null : _chapterNames.indexOf(unfinished);
    }
    _loadedLocally = true;
  }

  /// Creates one new gameId and charges exactly one FREE start.
  /// The charge is rolled back only if the local game could not be created.
  Future<bool> startGameSession(
    int chapterIndex, {
    bool replaceActiveSession = false,
    bool retryAfterPendingFailure = false,
    required List<dynamic> initialTiles,
    Map<String, dynamic>? initialSave,
  }) async {
    if (chapterIndex < 0 || chapterIndex > 5) return false;
    if (!isChapterUnlocked(chapterIndex)) return false;
    if (_activeGameSessionId != null && !replaceActiveSession) return false;
    _initialBoard(initialTiles);

    if (!await LifeManager.consumeFreeGame()) return false;
    final previousBinding = SaveManager.gameSessionId;
    final gameId = _newUuid();
    try {
      await SaveManager.setGameSessionId(gameId);
      if (initialSave != null) {
        final candidate = Map<String, dynamic>.from(initialSave)
          ..['gameSessionId'] = gameId;
        await SaveManager.save(candidate);
      }
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      _loadedLocally = true;
      ToolManager.clearSessionUsage();
      return true;
    } catch (_) {
      if (previousBinding == null) {
        await SaveManager.clearGameSessionId();
      } else {
        await SaveManager.setGameSessionId(previousBinding);
      }
      await LifeManager.refundFailedGameCreation();
      return false;
    }
  }

  Future<bool> waitForPendingStartSession() async =>
      _activeGameSessionId != null;

  /// Resumes the exact saved gameId. This path never consumes a free start.
  Future<bool> resumeGameSession(
    int chapterIndex, {
    String? sessionId,
  }) async {
    if (chapterIndex < 0 || chapterIndex > 5) return false;
    final gameId = sessionId ?? _activeGameSessionId;
    if (gameId == null || gameId != SaveManager.gameSessionId) return false;
    if (!isChapterUnlocked(chapterIndex)) return false;

    final saved = SaveManager.loadCached(chapter: _chapterNames[chapterIndex]);
    final playable = saved != null &&
        saved['gameSessionId'] == gameId &&
        saved['gameOver'] != true &&
        saved['chapterComplete'] != true &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == 16;
    if (!playable) return false;

    _activeGameSessionId = gameId;
    _activeGameChapterIndex = chapterIndex;
    _loadedLocally = true;
    return true;
  }

  /// Reset/restart creates a new gameId and therefore consumes one more FREE
  /// start. A failed local write restores the prior game binding and allowance.
  Future<RestartGameSessionResult> restartGameSession(
    int chapterIndex, {
    Map<String, dynamic>? replayLog,
    String? replaySessionId,
    required List<dynamic> initialTiles,
    required Map<String, dynamic> replacementSave,
  }) async {
    if (chapterIndex < 0 ||
        chapterIndex > 5 ||
        !isChapterUnlocked(chapterIndex)) {
      return RestartGameSessionResult.rejected;
    }
    try {
      _initialBoard(initialTiles);
    } catch (_) {
      return RestartGameSessionResult.rejected;
    }
    if (!await LifeManager.consumeFreeGame()) {
      return RestartGameSessionResult.rejected;
    }

    final previousBinding = SaveManager.gameSessionId;
    final gameId = _newUuid();
    try {
      await SaveManager.setGameSessionId(gameId);
      final candidate = Map<String, dynamic>.from(replacementSave)
        ..['gameSessionId'] = gameId;
      await SaveManager.save(candidate);
      _activeGameSessionId = gameId;
      _activeGameChapterIndex = chapterIndex;
      _loadedLocally = true;
      ToolManager.clearSessionUsage();
      return RestartGameSessionResult.committed;
    } catch (_) {
      if (previousBinding == null) {
        await SaveManager.clearGameSessionId();
      } else {
        await SaveManager.setGameSessionId(previousBinding);
      }
      await LifeManager.refundFailedGameCreation();
      return RestartGameSessionResult.rejected;
    }
  }

  /// Returning Home with unfinishedExit preserves the exact local game.
  /// Game Over/abandonment ends that gameId but never refunds its start.
  Future<bool> abandonGameSession({
    String? sessionId,
    Map<String, dynamic>? replayLog,
    String reason = 'PLAYER_ABANDONED',
    bool unfinishedExit = false,
  }) async {
    if (unfinishedExit) return true;
    final gameId = sessionId ?? _activeGameSessionId;
    if (gameId == null) return true;
    if (_activeGameSessionId != null && _activeGameSessionId != gameId) {
      return false;
    }

    final chapterIndex = _activeGameChapterIndex;
    await SaveManager.clearGameSessionId();
    if (chapterIndex != null) {
      await SaveManager.clearChapter(_chapterNames[chapterIndex]);
    }
    _activeGameSessionId = null;
    _activeGameChapterIndex = null;
    _loadedLocally = true;
    ToolManager.clearSessionUsage();
    return true;
  }

  /// Completes local chapter progress and grants each Gold reward once.
  Future<bool> completeChapter({
    required int chapterIndex,
    required Map<String, dynamic> replayLog,
    int? effectiveScore,
    int newSpeciesCount = 0,
    int highestValue = 0,
  }) async {
    if (chapterIndex < 0 || chapterIndex > 5) return false;
    if (!LifeManager.hasPermanentUnlock && chapterIndex != 0) return false;

    final gameId = _activeGameSessionId ?? SaveManager.gameSessionId;
    if (gameId == null ||
        gameId != SaveManager.gameSessionId ||
        (_activeGameChapterIndex != null &&
            _activeGameChapterIndex != chapterIndex)) {
      return false;
    }
    final saved = SaveManager.loadCached(chapter: _chapterNames[chapterIndex]);
    if (saved == null ||
        saved['gameSessionId'] != gameId ||
        saved['chapterComplete'] != true) {
      return false;
    }
    final score = (effectiveScore ??
            (saved?['score'] is num ? (saved!['score'] as num).toInt() : 0))
        .clamp(0, 1 << 30)
        .toInt();
    final highest = highestValue > 0
        ? highestValue
        : (saved?['highestEvolutionValue'] is num
            ? (saved!['highestEvolutionValue'] as num).toInt()
            : (1 << (chapterIndex + 12)));
    final speciesCount = newSpeciesCount > 0
        ? newSpeciesCount
        : (saved?['speciesMergedThisGame'] is List
            ? (saved!['speciesMergedThisGame'] as List).whereType<num>().toSet().length
            : 0);

    if (gameId != null) {
      await GoldManager.settleGame(
        gameId: gameId,
        effectiveScore: score,
        newSpeciesCount: speciesCount,
        highestValue: highest,
      );
    }

    await SaveManager.saveLocalChapterCompletion(
      chapterIndex: chapterIndex,
      score: score,
    );
    await GoldManager.awardChapterCompletion(chapterIndex);
    final completedChapters = SaveManager.localChapterProgress.keys.toSet();
    if (List<String>.generate(6, (index) => 'C${index + 1}')
        .every(completedChapters.contains)) {
      await GoldManager.awardAllChaptersCompletion();
    }

    if (_activeGameChapterIndex == chapterIndex ||
        (gameId != null && SaveManager.gameSessionId == gameId)) {
      _activeGameSessionId = null;
      _activeGameChapterIndex = null;
      await SaveManager.clearGameSessionId();
    }
    await refresh();
    return true;
  }
}
