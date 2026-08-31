import 'dart:math';

import '../models/game_board.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'tool_manager.dart';

class GameEngine {
  GameEngine({Random? random, GameChapter chapter = GameChapter.ocean})
    : _random = random ?? Random(),
      // Keep the public `chapter` parameter name for all existing callers.
      // ignore: prefer_initializing_formals
      _chapter = chapter {
    _initializeTools();
    reset();
  }

  static const int boardSize = 4;

  final Random _random;
  final GameChapter _chapter;

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

  GameBoard get board => _board;
  GameChapter get chapter => _chapter;
  ToolManager get toolManager => _toolManager;
  bool get hasTools => _toolManager.hasTools;
  int get availableToolCount => _toolManager.availableToolCount;
  bool get canUseRevive => _toolManager.canUse(GameToolType.revive);
  bool get canUseTimeRewind =>
      _toolManager.canUse(GameToolType.timeRewind) && _hasPreviousState;
  bool get canUsePositionSwap => _toolManager.canUse(GameToolType.positionSwap);
  bool get canUseDuplicate => _toolManager.canUse(GameToolType.duplicate);
  bool get canUseHistoryRestore => false;
  bool get hasPreviousState => _hasPreviousState;

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

  void _initializeTools() {
    _toolManager = ToolManager(chapter: _chapter);
  }

  bool useRevive(int row, int column) {
    if (chapterComplete || !canUseRevive) return false;
    if (row < 0 || row >= boardSize || column < 0 || column >= boardSize) {
      return false;
    }
    if (_board.tileAt(row, column) == null) return false;
    if (!_toolManager.use(GameToolType.revive)) return false;
    _board.setTile(row, column, null);
    gameOver = false;
    return true;
  }

  bool useTimeRewind() {
    if (chapterComplete || !canUseTimeRewind) return false;
    if (_previousBoard == null) return false;
    if (!_toolManager.use(GameToolType.timeRewind)) return false;
    _restorePreviousState();
    _hasPreviousState = false;
    _previousBoard = null;
    return true;
  }

  bool usePositionSwap(
    int firstRow,
    int firstColumn,
    int secondRow,
    int secondColumn,
  ) {
    if (_chapter != GameChapter.land &&
        _chapter != GameChapter.sky &&
        _chapter != GameChapter.history &&
        _chapter != GameChapter.tech) {
      return false;
    }
    if (chapterComplete || !canUsePositionSwap) return false;
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
    if (firstRow == secondRow && firstColumn == secondColumn) return false;
    final first = _board.tileAt(firstRow, firstColumn);
    final second = _board.tileAt(secondRow, secondColumn);
    if (first == null || second == null) return false;
    if (!_toolManager.use(GameToolType.positionSwap)) return false;
    _board.setTile(firstRow, firstColumn, second);
    _board.setTile(secondRow, secondColumn, first);
    gameOver = false;
    return true;
  }

  bool useDuplicate(
    int sourceRow,
    int sourceColumn,
    int targetRow,
    int targetColumn,
  ) {
    if ((_chapter != GameChapter.history && _chapter != GameChapter.tech) ||
        chapterComplete) {
      return false;
    }

    if (!canUseDuplicate) return false;

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

    if (source == null || source.value >= 512) return false;
    if (target != null) return false;

    if (!_toolManager.use(GameToolType.duplicate)) return false;

    _board.setTile(
      targetRow,
      targetColumn,
      GameTile(value: source.value, chapter: _chapter),
    );

    gameOver = false;
    return true;
  }

  bool useHistoryRestore(int row, int column) => false;

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
    hasReached2048 = false;
    hasReached4096 = false;
    hasReached8192 = false;
    hasReached16384 = false;
    gameOver = false;
    chapterComplete = false;
    score = 0;
    _spawnTile();
    _spawnTile();
  }

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
    if (expected == null || expected != _chapter) return;
    final value = targetValue;
    _board = GameBoard(size: boardSize);
    _board.setTile(0, 0, GameTile(value: value, chapter: _chapter));
    hasReached2048 = value >= 2048;
    hasReached4096 = value >= 4096;
    hasReached8192 = value >= 8192;
    hasReached16384 = value >= 16384;
    chapterComplete = true;
    gameOver = true;
    score = chapterNumber * 10000;
    _hasPreviousState = false;
    _previousBoard = null;
    _updateBestScore();
  }

  void debugCompleteChapter1() => debugCompleteChapter(1);
  void debugCompleteChapter2() => debugCompleteChapter(2);
  void debugCompleteChapter3() => debugCompleteChapter(3);
  void debugCompleteChapter4() => debugCompleteChapter(4);
  void debugCompleteChapter5() => debugCompleteChapter(5);
  void debugCompleteChapter6() => debugCompleteChapter(6);

  bool moveUp() => _move(_board.moveUp);
  bool moveDown() => _move(_board.moveDown);
  bool moveLeft() => _move(_board.moveLeft);
  bool moveRight() => _move(_board.moveRight);

  bool _move(bool Function() move) {
    if (gameOver || chapterComplete) return false;
    _savePreviousState();
    final changed = move();
    if (!changed) {
      _hasPreviousState = false;
      _previousBoard = null;
      gameOver = _isGameOver();
      return false;
    }
    _updateScore();
    _updateMilestones();
    if (chapterComplete) {
      gameOver = true;
      _hasPreviousState = false;
      _previousBoard = null;
      _updateBestScore();
      return true;
    }
    if (!_board.isFull) _spawnTile();
    gameOver = _isGameOver();
    _updateBestScore();
    return true;
  }

  void _updateScore() {
    score += _board.lastMergeScore;
    _updateBestScore();
  }

  void _updateBestScore() {
    if (score > bestScore) bestScore = score;
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

  void _spawnTile() {
    final empty = <int>[];
    for (var i = 0; i < boardSize * boardSize; i++) {
      if (_board.tiles[i] == null) empty.add(i);
    }
    if (empty.isEmpty) return;
    final index = empty[_random.nextInt(empty.length)];
    final value = _random.nextDouble() < 0.9 ? 2 : 4;
    _board.setTile(
      index ~/ boardSize,
      index % boardSize,
      GameTile(value: value, chapter: _chapter),
    );
  }

  bool _isGameOver() {
    if (!_board.isFull) return false;
    for (var row = 0; row < boardSize; row++) {
      for (var column = 0; column < boardSize; column++) {
        final current = _board.tileAt(row, column);
        if (current == null) return false;
        if (column + 1 < boardSize &&
            current.value == _board.tileAt(row, column + 1)?.value &&
            !current.isFinal) {
          return false;
        }
        if (row + 1 < boardSize &&
            current.value == _board.tileAt(row + 1, column)?.value &&
            !current.isFinal) {
          return false;
        }
      }
    }
    return true;
  }
}
