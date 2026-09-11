// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../models/game_board.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'save_manager.dart';
import 'life_manager.dart';
import 'tool_manager.dart';

class GameEngine {
  GameEngine({Random? random, GameChapter chapter = GameChapter.ocean})
    : _random = random ?? Random(),
      _chapter = chapter {
    _autoSaveEnabled = false;
    _initializeTools();
    reset();

    final saved = SaveManager.loadCached(
      chapter: _chapter.name,
    );
    if (saved != null && _shouldRestoreSavedChapter(saved)) {
      restoreFromSaveData(saved);
    }

    _autoSaveEnabled = true;

    // Restore life state from the persistent save.
    _restoreLifeStateFromSave(saved ?? <String, dynamic>{});

    // A genuinely new board consumes exactly one life.
    // Restored boards keep their existing board life.
    final hasSavedBoard = saved != null &&
        _shouldRestoreSavedChapter(saved) &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == boardSize * boardSize;

    if (!hasSavedBoard) {
      consumeLifeForGameEntry();
    }

    // A restored active game continues counting only when the page
    // explicitly resumes it. This prevents time spent outside the app
    // from being counted as active game time.
    _gameTimerRunning = false;
    _gameTimerStartedAt = null;

    _saveLocal();
  }

  static const int boardSize = 4;

  // ============================================================
  // Life
  // ============================================================

  static const int maxLives = LifeManager.normalCap;

  /// Kept as an engine-facing alias for the persistent life system.
  static const Duration lifeRegenerationInterval =
      LifeManager.regenerationInterval;

  int _lives = maxLives;

  /// Unix timestamp in milliseconds for the next life regeneration.
  int? _nextLifeAtMillis;

  /// Prevents the same Game Over from deducting life more than once.
  bool _boardLifeActive = false;

  int get lives => _lives;

  bool get hasLife => _lives > 0;

  int? get nextLifeAtMillis => _nextLifeAtMillis;

  Duration? get lifeRegenerationRemaining {
    final next = _nextLifeAtMillis;
    if (next == null || _lives >= maxLives) {
      return null;
    }

    final remaining = DateTime.fromMillisecondsSinceEpoch(
      next,
    ).difference(DateTime.now());

    if (remaining.isNegative || remaining == Duration.zero) {
      return Duration.zero;
    }

    return remaining;
  }

  /// Recalculates life using real wall-clock time.
  ///
  /// This works even when the app has been completely closed.
  void updateLifeFromRealTime() {
    _lives = LifeManager.lifeCount;
    _nextLifeAtMillis = LifeManager.nextLifeAtMillis;
    _saveLocal();
  }

  /// Deduct one life for a real Game Over.
  ///
  /// This is intentionally separate from reset/restart so merely leaving
  /// the app never deducts a life.
  bool deductLifeForGameOver() {
    if (!gameOver || chapterComplete || !_boardLifeActive) {
      return false;
    }

    _boardLifeActive = false;

    _stopGameTimer();
    _saveLocal();
    return true;
  }

  /// Deduct one life when the player explicitly chooses Restart.
  ///
  /// Restart is a new game, so this is a separate life deduction from
  /// the Game Over that caused the restart screen.
  bool deductLifeForRestart() {
    if (_lives <= 0) {
      return false;
    }

    _deductLife();

    return true;
  }

  /// Consume one life when a gameplay page is entered.
  bool consumeLifeForGameEntry() {
    if (_boardLifeActive) {
      return true;
    }

    if (_lives <= 0) {
      return false;
    }

    _deductLife();
    _boardLifeActive = true;
    _saveLocal();
    return true;
  }

  void _deductLife() {
    if (!LifeManager.consumeLifeNow()) return;

    _lives = LifeManager.lifeCount;
    _nextLifeAtMillis = LifeManager.nextLifeAtMillis;
  }

  void _restoreLifeStateFromSave(Map<String, dynamic> data) {
    // LifeManager is the single persistent source of truth. Ignore the
    // duplicated legacy fields in gameplay saves so an old erroneous zero
    // cannot overwrite the current life balance.
    _lives = LifeManager.lifeCount;
    _nextLifeAtMillis = LifeManager.nextLifeAtMillis;

    _boardLifeActive = data['boardLifeActive'] == true;

    updateLifeFromRealTime();
  }

  // ============================================================
  // Game Timer
  // ============================================================

  int _gameElapsedSeconds = 0;
  DateTime? _gameTimerStartedAt;
  bool _gameTimerRunning = false;

  int get gameElapsedSeconds {
    if (!_gameTimerRunning || _gameTimerStartedAt == null) {
      return _gameElapsedSeconds;
    }

    final elapsed = DateTime.now().difference(_gameTimerStartedAt!).inSeconds;

    return _gameElapsedSeconds + elapsed;
  }

  bool get gameTimerRunning => _gameTimerRunning;

  /// Start/resume active gameplay time.
  ///
  /// Time spent while the app is in the background is never included.
  void startGameTimer() {
    if (gameOver || chapterComplete || _gameTimerRunning) {
      return;
    }

    _gameTimerStartedAt = DateTime.now();
    _gameTimerRunning = true;

    _saveLocal();
  }

  /// Pause active gameplay time.
  ///
  /// This should be called when the app enters the background.
  void pauseGameTimer() {
    if (!_gameTimerRunning || _gameTimerStartedAt == null) {
      return;
    }

    _gameElapsedSeconds += DateTime.now()
        .difference(_gameTimerStartedAt!)
        .inSeconds;

    _gameTimerStartedAt = null;
    _gameTimerRunning = false;

    _saveLocal();
  }

  /// Stop the game timer permanently.
  ///
  /// Used for Game Over and Chapter Complete.
  void stopGameTimer() {
    _stopGameTimer();
    _saveLocal();
  }

  void _stopGameTimer() {
    if (_gameTimerRunning && _gameTimerStartedAt != null) {
      _gameElapsedSeconds += DateTime.now()
          .difference(_gameTimerStartedAt!)
          .inSeconds;
    }

    _gameTimerStartedAt = null;
    _gameTimerRunning = false;
  }

  String get formattedGameTime {
    final totalSeconds = gameElapsedSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // Core state
  // ============================================================

  final Random _random;
  GameChapter _chapter;
  bool _autoSaveEnabled = false;
  Future<void> _saveQueue = Future<void>.value();

  late GameBoard _board;
  late ToolManager _toolManager;

  List<int?>? _previousBoard;
  int _previousScore = 0;
  bool _previousHasReached2048 = false;
  bool _previousHasReached4096 = false;
  bool _previousHasReached8192 = false;
  bool _previousHasReached16384 = false;
  bool _previousGameOver = false;
  bool _previousChapterComplete = false;
  bool _hasPreviousState = false;

  final List<int> _newEvolutionValuesThisMove = <int>[];

  GameBoard get board => _board;
  GameChapter get chapter => _chapter;
  ToolManager get toolManager => _toolManager;
  bool get hasTools => _toolManager.hasTools;
  int get availableToolCount => _toolManager.availableToolCount;

  bool get canUseRevive =>
      !gameOver && !chapterComplete && _toolManager.canUse(GameToolType.revive);

  bool get canUseTimeRewind =>
      !gameOver &&
      !chapterComplete &&
      _toolManager.canUse(GameToolType.timeRewind) &&
      _hasPreviousState;

  bool get canUsePositionSwap =>
      !gameOver &&
      !chapterComplete &&
      _toolManager.canUse(GameToolType.positionSwap);

  bool get canUseDuplicate =>
      !gameOver &&
      !chapterComplete &&
      _toolManager.canUse(GameToolType.duplicate);

  bool get canUseHistoryRestore => false;
  bool get hasPreviousState => _hasPreviousState;

  /// The highest stage the player has ever reached in this chapter.
  /// This is intentionally independent from the current board so Undo
  /// cannot make the evolution label move backwards.
  int _highestEvolutionValue = 2;

  int get highestEvolutionValue => _highestEvolutionValue;

  /// Total score removed by tool usage in the current game.
  int _toolPenaltyTotal = 0;

  int get toolPenaltyTotal => _toolPenaltyTotal;

  /// New stages first reached by the most recent action, in order.
  List<int> get newEvolutionValuesThisMove =>
      List.unmodifiable(_newEvolutionValuesThisMove);

  bool hasReached2048 = false;
  bool hasReached4096 = false;
  bool hasReached8192 = false;
  bool hasReached16384 = false;
  bool gameOver = false;
  bool chapterComplete = false;
  int score = 0;
  int bestScore = 0;

  int get targetValue {
    return switch (_chapter) {
      GameChapter.ocean => 4096,
      GameChapter.land => 8192,
      GameChapter.sky => 16384,
      GameChapter.history => 32768,
      GameChapter.tech => 65536,
      GameChapter.universe => 131072,
    };
  }

  int get highestValue => _board.tiles.whereType<GameTile>().fold<int>(
    0,
    (highest, tile) => tile.value > highest ? tile.value : highest,
  );

  // ============================================================
  // Save
  // ============================================================

  Map<String, dynamic> createSaveData() {
    return <String, dynamic>{
      'chapter': _chapter.name,
      'tiles': _board.tiles.map((tile) => tile?.value).toList(),
      'score': score,
      'bestScore': bestScore,
      'toolPenaltyTotal': _toolPenaltyTotal,
      'hasReached2048': hasReached2048,
      'hasReached4096': hasReached4096,
      'hasReached8192': hasReached8192,
      'hasReached16384': hasReached16384,
      'highestEvolutionValue': _highestEvolutionValue,
      'gameOver': gameOver,
      'chapterComplete': chapterComplete,

      // Life state.
      'lives': _lives,
      'nextLifeAtMillis': _nextLifeAtMillis,
      'boardLifeActive': _boardLifeActive,

      // Active gameplay time.
      'gameElapsedSeconds': _gameElapsedSeconds,
      'gameTimerRunning': _gameTimerRunning,
      'gameTimerStartedAt': _gameTimerStartedAt?.millisecondsSinceEpoch,
    };
  }

  void _saveLocal() {
    if (!_autoSaveEnabled) return;

    final snapshot = createSaveData();

    _saveQueue = _saveQueue.then((_) => SaveManager.save(snapshot));
  }

  bool _shouldRestoreSavedChapter(Map<String, dynamic> data) {
    final savedChapter = data['chapter'];
    if (savedChapter is! String) return false;

    return _chapter == GameChapter.ocean || savedChapter == _chapter.name;
  }

  bool restoreFromSaveData(Map<String, dynamic> data) {
    final savedChapter = data['chapter'];
    if (savedChapter is! String) return false;

    final restoredChapter = GameChapter.values.cast<GameChapter?>().firstWhere(
      (value) => value?.name == savedChapter,
      orElse: () => null,
    );

    if (restoredChapter == null) return false;

    final rawTiles = data['tiles'];

    if (rawTiles is! List || rawTiles.length != boardSize * boardSize) {
      return false;
    }

    final values = <int?>[];

    for (final raw in rawTiles) {
      if (raw == null) {
        values.add(null);
        continue;
      }

      if (raw is! num || raw.toInt() < 2) {
        return false;
      }

      values.add(raw.toInt());
    }

    _chapter = restoredChapter;
    _initializeTools();

    _board = GameBoard(size: boardSize);

    for (var index = 0; index < values.length; index++) {
      final value = values[index];

      if (value == null) continue;

      _board.setTile(
        index ~/ boardSize,
        index % boardSize,
        GameTile(value: value, chapter: _chapter),
      );
    }

    score = _readInt(data['score']);
    bestScore = _readInt(data['bestScore']);
    _toolPenaltyTotal = _readInt(data['toolPenaltyTotal']);

    hasReached2048 = data['hasReached2048'] == true;
    hasReached4096 = data['hasReached4096'] == true;
    hasReached8192 = data['hasReached8192'] == true;
    hasReached16384 = data['hasReached16384'] == true;

    final savedHighestEvolution = _readInt(data['highestEvolutionValue']);

    _highestEvolutionValue = savedHighestEvolution >= 2
        ? savedHighestEvolution
        : _highestStageFromBoard();

    if (_highestEvolutionValue < 2) {
      _highestEvolutionValue = 2;
    }

    gameOver = data['gameOver'] == true;
    chapterComplete = data['chapterComplete'] == true;

    // Restore game time.
    _gameElapsedSeconds = max(0, _readInt(data['gameElapsedSeconds']));

    // Never continue the active timer automatically during construction.
    // The page explicitly starts it when the app is active.
    _gameTimerRunning = false;
    _gameTimerStartedAt = null;

    _newEvolutionValuesThisMove.clear();

    _previousBoard = null;
    _hasPreviousState = false;

    _previousScore = 0;
    _previousHasReached2048 = false;
    _previousHasReached4096 = false;
    _previousHasReached8192 = false;
    _previousHasReached16384 = false;
    _previousGameOver = false;
    _previousChapterComplete = false;

    _updateBestScore();

    return true;
  }

  int _highestStageFromBoard() {
    final boardHighest = highestValue;
    return boardHighest >= 2 ? boardHighest : 2;
  }

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  void _initializeTools() {
    _toolManager = ToolManager(chapter: _chapter);
  }

  void refreshToolProgress() {
    _toolManager.refreshFromSavedProgress();
  }

  void _deductToolScore(int amount) {
    if (amount <= 0) return;

    final before = score;

    score = max(0, score - amount);

    _toolPenaltyTotal += before - score;

    _updateBestScore();
  }

  // ============================================================
  // Tools
  // ============================================================

  bool useRevive(int row, int column) {
    if (gameOver || chapterComplete || !canUseRevive) {
      return false;
    }

    if (row < 0 || row >= boardSize || column < 0 || column >= boardSize) {
      return false;
    }

    final tile = _board.tileAt(row, column);

    if (tile == null) return false;

    if (!_toolManager.use(GameToolType.revive)) {
      return false;
    }

    _board.setTile(row, column, null);

    _deductToolScore(tile.value);

    _newEvolutionValuesThisMove.clear();

    if (_board.tiles.every((tile) => tile == null)) {
      _spawnTile();
    }

    _saveLocal();

    return true;
  }

  bool useTimeRewind() {
    if (gameOver || chapterComplete || !canUseTimeRewind) {
      return false;
    }

    if (_previousBoard == null) {
      return false;
    }

    if (!_toolManager.use(GameToolType.timeRewind)) {
      return false;
    }

    final revertedScore = max(0, score - _previousScore);

    _restorePreviousState();

    _toolPenaltyTotal += revertedScore;

    _hasPreviousState = false;
    _previousBoard = null;

    _newEvolutionValuesThisMove.clear();

    _saveLocal();

    return true;
  }

  bool usePositionSwap(
    int firstRow,
    int firstColumn,
    int secondRow,
    int secondColumn,
  ) {
    if (!SaveManager.developerAllTools &&
        _chapter != GameChapter.land &&
        _chapter != GameChapter.sky &&
        _chapter != GameChapter.history &&
        _chapter != GameChapter.tech) {
      return false;
    }

    if (gameOver || chapterComplete || !canUsePositionSwap) {
      return false;
    }

    if (firstRow < 0 ||
        firstRow >= boardSize ||
        firstColumn < 0 ||
        firstColumn >= boardSize ||
        secondRow < 0 ||
        secondRow >= boardSize ||
        secondColumn < 0 ||
        secondColumn >= boardSize) {
      return false;
    }

    if (firstRow == secondRow && firstColumn == secondColumn) {
      return false;
    }

    final first = _board.tileAt(firstRow, firstColumn);
    final second = _board.tileAt(secondRow, secondColumn);

    if (first == null || second == null) {
      return false;
    }

    if (!_toolManager.use(GameToolType.positionSwap)) {
      return false;
    }

    _board.setTile(firstRow, firstColumn, second);
    _board.setTile(secondRow, secondColumn, first);

    _deductToolScore(first.value + second.value);

    _newEvolutionValuesThisMove.clear();

    _saveLocal();

    return true;
  }

  bool useDuplicate(
    int sourceRow,
    int sourceColumn,
    int targetRow,
    int targetColumn,
  ) {
    if ((!SaveManager.developerAllTools &&
        _chapter != GameChapter.history &&
        _chapter != GameChapter.tech) ||
        chapterComplete) {
      return false;
    }

    if (gameOver || !canUseDuplicate) {
      return false;
    }

    if (sourceRow < 0 ||
        sourceRow >= boardSize ||
        sourceColumn < 0 ||
        sourceColumn >= boardSize ||
        targetRow < 0 ||
        targetRow >= boardSize ||
        targetColumn < 0 ||
        targetColumn >= boardSize) {
      return false;
    }

    if (sourceRow == targetRow && sourceColumn == targetColumn) {
      return false;
    }

    final source = _board.tileAt(sourceRow, sourceColumn);
    final target = _board.tileAt(targetRow, targetColumn);

    if (source == null) return false;
    if (target != null) return false;

    if (!_toolManager.use(GameToolType.duplicate)) {
      return false;
    }

    _board.setTile(
      targetRow,
      targetColumn,
      GameTile(value: source.value, chapter: _chapter),
    );

    _deductToolScore(source.value);

    _newEvolutionValuesThisMove.clear();

    _recordHighestEvolutionValue(source.value);

    _saveLocal();

    return true;
  }

  bool useHistoryRestore(int row, int column) => false;

  // ============================================================
  // Undo
  // ============================================================

  void _savePreviousState() {
    _previousBoard = _board.tiles.map<int?>((tile) => tile?.value).toList();

    _previousScore = score;

    _previousHasReached2048 = hasReached2048;
    _previousHasReached4096 = hasReached4096;
    _previousHasReached8192 = hasReached8192;
    _previousHasReached16384 = hasReached16384;

    _previousGameOver = gameOver;
    _previousChapterComplete = chapterComplete;

    _hasPreviousState = true;
  }

  void _restorePreviousState() {
    final snapshot = _previousBoard;

    if (snapshot == null) return;

    _board = GameBoard(size: boardSize);

    for (var index = 0; index < snapshot.length; index++) {
      final value = snapshot[index];

      if (value == null) continue;

      _board.setTile(
        index ~/ boardSize,
        index % boardSize,
        GameTile(value: value, chapter: _chapter),
      );
    }

    score = _previousScore;

    hasReached2048 = _previousHasReached2048;
    hasReached4096 = _previousHasReached4096;
    hasReached8192 = _previousHasReached8192;
    hasReached16384 = _previousHasReached16384;

    gameOver = _previousGameOver;
    chapterComplete = _previousChapterComplete;
  }

  // ============================================================
  // Reset / Restart
  // ============================================================

  void reset() {
    _board = GameBoard(size: boardSize);

    _toolManager.reset();

    _previousBoard = null;
    _previousScore = 0;

    _previousHasReached2048 = false;
    _previousHasReached4096 = false;
    _previousHasReached8192 = false;
    _previousHasReached16384 = false;

    _previousGameOver = false;
    _previousChapterComplete = false;

    _hasPreviousState = false;

    _newEvolutionValuesThisMove.clear();

    _highestEvolutionValue = 2;
    _toolPenaltyTotal = 0;

    hasReached2048 = false;
    hasReached4096 = false;
    hasReached8192 = false;
    hasReached16384 = false;

    gameOver = false;
    chapterComplete = false;

    score = 0;

    // A new game always starts a fresh active-game timer.
    _gameElapsedSeconds = 0;
    _gameTimerStartedAt = null;
    _gameTimerRunning = false;

    // Reset Game Over deduction state for the new game.
    _boardLifeActive = false;

    _spawnTile();
    _spawnTile();

    _saveLocal();
  }

  /// Explicit restart requested by the player.
  ///
  /// The restart itself consumes one life. This is intentionally separate
  /// from reset(), because reset() is also used during engine construction
  /// and other internal flows.
  bool restart() {
    updateLifeFromRealTime();

    if (_lives <= 0) {
      return false;
    }

    deductLifeForRestart();

    reset();

    _saveLocal();

    return true;
  }

  // ============================================================
  // Debug
  // ============================================================

  void debugCompleteChapter(int chapterNumber) {
    final expected = switch (chapterNumber) {
      1 => GameChapter.ocean,
      2 => GameChapter.land,
      3 => GameChapter.sky,
      4 => GameChapter.history,
      5 => GameChapter.tech,
      6 => GameChapter.universe,
      _ => null,
    };

    if (expected == null || expected != _chapter) {
      return;
    }

    final value = targetValue;

    _board = GameBoard(size: boardSize);

    _board.setTile(0, 0, GameTile(value: value, chapter: _chapter));

    _highestEvolutionValue = value;

    _newEvolutionValuesThisMove.clear();

    hasReached2048 = value >= 2048;
    hasReached4096 = value >= 4096;
    hasReached8192 = value >= 8192;
    hasReached16384 = value >= 16384;

    chapterComplete = true;
    gameOver = true;

    score = chapterNumber * 10000;
    _toolPenaltyTotal = 0;

    _hasPreviousState = false;
    _previousBoard = null;

    // Debug completion does not consume life.
    _boardLifeActive = false;

    _stopGameTimer();

    _updateBestScore();

    _saveLocal();
  }

  void debugCompleteChapter1() => debugCompleteChapter(1);
  void debugCompleteChapter2() => debugCompleteChapter(2);
  void debugCompleteChapter3() => debugCompleteChapter(3);
  void debugCompleteChapter4() => debugCompleteChapter(4);
  void debugCompleteChapter5() => debugCompleteChapter(5);
  void debugCompleteChapter6() => debugCompleteChapter(6);

  // ============================================================
  // Moves
  // ============================================================

  bool moveUp() => _move(_board.moveUp);
  bool moveDown() => _move(_board.moveDown);
  bool moveLeft() => _move(_board.moveLeft);
  bool moveRight() => _move(_board.moveRight);

  bool _move(bool Function() move) {
    if (gameOver || chapterComplete) {
      return false;
    }

    // Start the active timer when the first actual move occurs.
    if (!_gameTimerRunning) {
      startGameTimer();
    }

    _newEvolutionValuesThisMove.clear();

    _savePreviousState();

    final changed = move();

    if (!changed) {
      _hasPreviousState = false;
      _previousBoard = null;

      gameOver = _isGameOver();

      if (gameOver) {
        deductLifeForGameOver();
      }

      _saveLocal();

      return false;
    }

    _updateScore();
    _updateEvolutionHistory();
    _updateMilestones();

    if (chapterComplete) {
      gameOver = true;

      _hasPreviousState = false;
      _previousBoard = null;

      _stopGameTimer();

      _updateBestScore();
      _saveLocal();

      return true;
    }

    if (!_board.isFull) {
      _spawnTile();
    }

    gameOver = _isGameOver();

    if (gameOver) {
      deductLifeForGameOver();
    }

    _updateBestScore();
    _saveLocal();

    return true;
  }

  // ============================================================
  // Score / evolution
  // ============================================================

  void _updateScore() {
    score += _board.lastMergeScore;
    _updateBestScore();
  }

  void _recordHighestEvolutionValue(int value) {
    if (value <= _highestEvolutionValue) {
      return;
    }

    _highestEvolutionValue = value;
    _newEvolutionValuesThisMove.add(value);
  }

  void _updateEvolutionHistory() {
    for (final value in _board.lastMergedValues) {
      _recordHighestEvolutionValue(value);
    }
  }

  void _updateBestScore() {
    if (score > bestScore) {
      bestScore = score;
    }
  }

  void _updateMilestones() {
    hasReached2048 = hasReached2048 || _board.hasReached2048;

    hasReached4096 = hasReached4096 || _board.hasReached4096;

    hasReached8192 = hasReached8192 || _board.hasReached8192;

    hasReached16384 = hasReached16384 || highestValue >= 16384;

    if (highestValue >= targetValue) {
      chapterComplete = true;

      switch (_chapter) {
        case GameChapter.ocean:
          hasReached4096 = true;
          break;

        case GameChapter.land:
          hasReached8192 = true;
          break;

        case GameChapter.sky:
          hasReached16384 = true;
          break;

        case GameChapter.history:
        case GameChapter.tech:
        case GameChapter.universe:
          break;
      }
    }
  }

  bool _isGameOver() {
    if (!_board.isFull) {
      return false;
    }

    return !_board.hasAvailableMerge;
  }

  void _spawnTile() {
    final empty = _board.emptyPositions;

    if (empty.isEmpty) {
      return;
    }

    final position = empty[_random.nextInt(empty.length)];

    final value = _random.nextInt(10) == 0 ? 4 : 2;

    _board.setTile(
      position.row,
      position.column,
      GameTile(value: value, chapter: _chapter),
    );

    _recordHighestEvolutionValue(value);
  }
}








