import 'dart:math';

import '../models/game_board.dart';
import '../models/game_tile.dart';

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random() {
    reset();
  }

  static const int boardSize = 4;

  final Random _random;
  late GameBoard _board;

  GameBoard get board => _board;

  bool hasReached2048 = false;
  bool hasReached4096 = false;
  bool gameOver = false;

  void reset() {
    _board = GameBoard(size: boardSize);
    hasReached2048 = false;
    hasReached4096 = false;
    gameOver = false;
    _spawnTile();
    _spawnTile();
  }

  bool moveUp() => _move(_board.moveUp);
  bool moveDown() => _move(_board.moveDown);
  bool moveLeft() => _move(_board.moveLeft);
  bool moveRight() => _move(_board.moveRight);

  bool _move(bool Function() move) {
    if (gameOver) return false;

    final changed = move();
    if (!changed) {
      gameOver = _isGameOver();
      return false;
    }

    hasReached2048 = hasReached2048 || _board.hasReached2048;
    hasReached4096 = hasReached4096 || _board.hasReached4096;

    if (!_board.isFull) {
      _spawnTile();
    }

    gameOver = _isGameOver();
    return true;
  }

  void _spawnTile() {
    final empty = <int>[];
    for (var i = 0; i < boardSize * boardSize; i++) {
      if (_board.tiles[i] == null) empty.add(i);
    }
    if (empty.isEmpty) return;

    final index = empty[_random.nextInt(empty.length)];
    final value = _random.nextDouble() < 0.9 ? 2 : 4;
    final row = index ~/ boardSize;
    final column = index % boardSize;
    _board.setTile(row, column, GameTile(value: value));
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
