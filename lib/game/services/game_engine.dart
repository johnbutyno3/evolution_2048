import 'dart:math';

import '../models/game_board.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'tool_manager.dart';

class GameEngine {
  GameEngine({
    Random? random,
    this._chapter = GameChapter.ocean,
  }) : _random = random ?? Random() {
    _initializeTools();
    reset();
  }

  static const int boardSize = 4;

  final Random _random;
  final GameChapter _chapter;

  late GameBoard _board;
  late ToolManager _toolManager;

  // ============================================================
  // Time Rewind snapshot
  // ============================================================

  List<int?>? _previousBoard;
  int _previousScore = 0;
  bool _previousHasReached2048 = false;
  bool _previousHasReached4096 = false;
  bool _previousHasReached8192 = false;
  bool _previousHasReached16384 = false;
  bool _previousGameOver = false;
  bool _previousChapterComplete = false;

  bool _hasPreviousState = false;

  // ============================================================
  // Basic getters
  // ============================================================

  GameBoard get board => _board;

  GameChapter get chapter => _chapter;

  ToolManager get toolManager => _toolManager;

  bool get hasTools =>
      _toolManager.hasTools;

  int get availableToolCount =>
      _toolManager.availableToolCount;

  bool get canUseRevive =>
      _toolManager.canUse(GameToolType.revive);

  bool get canUseTimeRewind =>
      _toolManager.canUse(
        GameToolType.timeRewind,
      ) &&
      _hasPreviousState;

  bool get hasPreviousState =>
      _hasPreviousState;

  bool hasReached2048 = false;
  bool hasReached4096 = false;
  bool hasReached8192 = false;
  bool hasReached16384 = false;

  bool gameOver = false;
  bool chapterComplete = false;

  int score = 0;
  int bestScore = 0;

  // ============================================================
  // Chapter target
  // ============================================================

  int get targetValue {
    return switch (_chapter) {
      GameChapter.ocean => 4096,
      GameChapter.land => 8192,
      GameChapter.sky => 16384,
    };
  }

  // ============================================================
  // Highest value
  // ============================================================

  int get highestValue {
    return _board.tiles.whereType<GameTile>().fold<int>(
      0,
      (highest, tile) {
        return tile.value > highest
            ? tile.value
            : highest;
      },
    );
  }

  // ============================================================
  // Tools
  // ============================================================

  void _initializeTools() {
    _toolManager = ToolManager(
      chapter: _chapter,
    );
  }

  // ============================================================
  // Revive
  // ============================================================

  /// Revive removes one creature from the board.
  ///
  /// Chapter 1:
  /// - Revive is unavailable.
  ///
  /// Chapter 2:
  /// - Revive can be used once.
  ///
  /// Chapter 3:
  /// - Revive is available as one of two tools.
  ///
  /// Returns true when a creature was successfully removed.
  bool useRevive(
    int row,
    int column,
  ) {
    if (gameOver || chapterComplete) {
      return false;
    }

    if (!canUseRevive) {
      return false;
    }

    if (row < 0 ||
        row >= boardSize ||
        column < 0 ||
        column >= boardSize) {
      return false;
    }

    final tile = _board.tileAt(
      row,
      column,
    );

    if (tile == null) {
      return false;
    }

    final used = _toolManager.use(
      GameToolType.revive,
    );

    if (!used) {
      return false;
    }

    _board.setTile(
      row,
      column,
      null,
    );

    gameOver = false;

    return true;
  }

  // ============================================================
  // Time Rewind
  // ============================================================

  /// Restores the board and game state to the position
  /// immediately before the most recent successful move.
  ///
  /// Only Chapter 3 has access to this tool.
  ///
  /// The tool can only be used once per chapter.
  bool useTimeRewind() {
    if (gameOver || chapterComplete) {
      return false;
    }

    if (!canUseTimeRewind) {
      return false;
    }

    if (_previousBoard == null) {
      return false;
    }

    final used = _toolManager.use(
      GameToolType.timeRewind,
    );

    if (!used) {
      return false;
    }

    _restorePreviousState();

    _hasPreviousState = false;
    _previousBoard = null;

    return true;
  }

  // ============================================================
  // Save previous state
  // ============================================================

  void _savePreviousState() {
    _previousBoard = _board.tiles.map<int?>(
      (tile) => tile?.value,
    ).toList();

    _previousScore = score;

    _previousHasReached2048 =
        hasReached2048;

    _previousHasReached4096 =
        hasReached4096;

    _previousHasReached8192 =
        hasReached8192;

    _previousHasReached16384 =
        hasReached16384;

    _previousGameOver =
        gameOver;

    _previousChapterComplete =
        chapterComplete;

    _hasPreviousState = true;
  }

  // ============================================================
  // Restore previous state
  // ============================================================

  void _restorePreviousState() {
    final snapshot = _previousBoard;

    if (snapshot == null) {
      return;
    }

    _board = GameBoard(
      size: boardSize,
    );

    for (
      var index = 0;
      index < snapshot.length;
      index++
    ) {
      final value = snapshot[index];

      if (value == null) {
        continue;
      }

      final row = index ~/ boardSize;
      final column = index % boardSize;

      _board.setTile(
        row,
        column,
        GameTile(
          value: value,
          chapter: _chapter,
        ),
      );
    }

    score = _previousScore;

    hasReached2048 =
        _previousHasReached2048;

    hasReached4096 =
        _previousHasReached4096;

    hasReached8192 =
        _previousHasReached8192;

    hasReached16384 =
        _previousHasReached16384;

    gameOver = _previousGameOver;
    chapterComplete =
        _previousChapterComplete;
  }

  // ============================================================
  // Reset
  // ============================================================

  void reset() {
    _board = GameBoard(
      size: boardSize,
    );

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

  // ============================================================
  // Debug - Chapter 1
  // ============================================================

  void debugCompleteChapter1() {
    if (_chapter != GameChapter.ocean) {
      return;
    }

    _board = GameBoard(
      size: boardSize,
    );

    _board.setTile(
      0,
      0,
      GameTile(
        value: 4096,
        chapter: GameChapter.ocean,
      ),
    );

    hasReached2048 = true;
    hasReached4096 = true;
    hasReached8192 = false;
    hasReached16384 = false;

    chapterComplete = true;
    gameOver = true;

    score = 10000;

    _hasPreviousState = false;
    _previousBoard = null;

    _updateBestScore();
  }

  // ============================================================
  // Debug - Chapter 2
  // ============================================================

  void debugCompleteChapter2() {
    if (_chapter != GameChapter.land) {
      return;
    }

    _board = GameBoard(
      size: boardSize,
    );

    _board.setTile(
      0,
      0,
      GameTile(
        value: 8192,
        chapter: GameChapter.land,
      ),
    );

    hasReached2048 = true;
    hasReached4096 = true;
    hasReached8192 = true;
    hasReached16384 = false;

    chapterComplete = true;
    gameOver = true;

    score = 20000;

    _hasPreviousState = false;
    _previousBoard = null;

    _updateBestScore();
  }

  // ============================================================
  // Debug - Chapter 3
  // ============================================================

  void debugCompleteChapter3() {
    if (_chapter != GameChapter.sky) {
      return;
    }

    _board = GameBoard(
      size: boardSize,
    );

    _board.setTile(
      0,
      0,
      GameTile(
        value: 16384,
        chapter: GameChapter.sky,
      ),
    );

    hasReached2048 = true;
    hasReached4096 = true;
    hasReached8192 = true;
    hasReached16384 = true;

    chapterComplete = true;
    gameOver = true;

    score = 30000;

    _hasPreviousState = false;
    _previousBoard = null;

    _updateBestScore();
  }

  // ============================================================
  // Movement
  // ============================================================

  bool moveUp() {
    if (gameOver || chapterComplete) {
      return false;
    }

    return _move(
      _board.moveUp,
    );
  }

  bool moveDown() {
    if (gameOver || chapterComplete) {
      return false;
    }

    return _move(
      _board.moveDown,
    );
  }

  bool moveLeft() {
    if (gameOver || chapterComplete) {
      return false;
    }

    return _move(
      _board.moveLeft,
    );
  }

  bool moveRight() {
    if (gameOver || chapterComplete) {
      return false;
    }

    return _move(
      _board.moveRight,
    );
  }

  bool _move(
    bool Function() move,
  ) {
    if (gameOver || chapterComplete) {
      return false;
    }

    // Save the state BEFORE the move.
    // It will become the state restored by Time Rewind.
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

    if (!_board.isFull) {
      _spawnTile();
    }

    gameOver = _isGameOver();

    _updateBestScore();

    return true;
  }

  // ============================================================
  // Score
  // ============================================================

  void _updateScore() {
    final moveScore =
        _board.lastMergeScore;

    score += moveScore;

    _updateBestScore();
  }

  void _updateBestScore() {
    if (score > bestScore) {
      bestScore = score;
    }
  }

  // ============================================================
  // Evolution milestones
  // ============================================================

  void _updateMilestones() {
    hasReached2048 =
        hasReached2048 ||
        _board.hasReached2048;

    hasReached4096 =
        hasReached4096 ||
        _board.hasReached4096;

    hasReached8192 =
        hasReached8192 ||
        _board.hasReached8192;

    hasReached16384 =
        hasReached16384 ||
        highestValue >= 16384;

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
      }
    }
  }

  // ============================================================
  // Spawn
  // ============================================================

  void _spawnTile() {
    final empty = <int>[];

    for (
      var i = 0;
      i < boardSize * boardSize;
      i++
    ) {
      if (_board.tiles[i] == null) {
        empty.add(i);
      }
    }

    if (empty.isEmpty) {
      return;
    }

    final index =
        empty[_random.nextInt(
      empty.length,
    )];

    final value =
        _random.nextDouble() < 0.9
            ? 2
            : 4;

    final row = index ~/ boardSize;
    final column = index % boardSize;

    _board.setTile(
      row,
      column,
      GameTile(
        value: value,
        chapter: _chapter,
      ),
    );
  }

  // ============================================================
  // Game Over
  // ============================================================

  bool _isGameOver() {
    if (!_board.isFull) {
      return false;
    }

    for (
      var row = 0;
      row < boardSize;
      row++
    ) {
      for (
        var column = 0;
        column < boardSize;
        column++
      ) {
        final current =
            _board.tileAt(
          row,
          column,
        );

        if (current == null) {
          return false;
        }

        if (
          column + 1 < boardSize &&
          current.value ==
              _board
                  .tileAt(
                    row,
                    column + 1,
                  )
                  ?.value &&
          !current.isFinal
        ) {
          return false;
        }

        if (
          row + 1 < boardSize &&
          current.value ==
              _board
                  .tileAt(
                    row + 1,
                    column,
                  )
                  ?.value &&
          !current.isFinal
        ) {
          return false;
        }
      }
    }

    return true;
  }
}