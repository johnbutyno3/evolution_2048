import 'game_tile.dart';

class GameBoard {
  GameBoard({int size = 4}) : assert(size == 4), _size = size {
    _tiles = List<GameTile?>.filled(_size * _size, null);
  }

  final int _size;
  late List<GameTile?> _tiles;

  int _lastMergeScore = 0;
  final List<int> _lastMergedValues = <int>[];

  int get size => _size;

  List<GameTile?> get tiles => List.unmodifiable(_tiles);

  bool get isFull => _tiles.every((tile) => tile != null);

  int get lastMergeScore => _lastMergeScore;

  int? get lastMergedValue =>
      _lastMergedValues.isEmpty ? null : _lastMergedValues.last;

  List<int> get lastMergedValues => List.unmodifiable(_lastMergedValues);

  /// Returns true when at least one legal adjacent merge is available.
  /// Final tiles cannot merge, matching the normal move rules.
  bool get hasAvailableMerge {
    for (var row = 0; row < _size; row++) {
      for (var column = 0; column < _size; column++) {
        final tile = tileAt(row, column);
        if (tile == null || tile.isFinal) continue;

        if (column + 1 < _size) {
          final right = tileAt(row, column + 1);
          if (right != null && right.value == tile.value && !right.isFinal) {
            return true;
          }
        }

        if (row + 1 < _size) {
          final down = tileAt(row + 1, column);
          if (down != null && down.value == tile.value && !down.isFinal) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Returns all currently empty board positions.
  List<({int row, int column})> get emptyPositions {
    final positions = <({int row, int column})>[];

    for (var row = 0; row < _size; row++) {
      for (var column = 0; column < _size; column++) {
        if (tileAt(row, column) == null) {
          positions.add((row: row, column: column));
        }
      }
    }

    return positions;
  }

  void reset() {
    _tiles = List<GameTile?>.filled(_size * _size, null);

    _lastMergeScore = 0;
    _lastMergedValues.clear();
  }

  void setTile(int row, int column, GameTile? tile) {
    _checkPosition(row, column);

    _tiles[_index(row, column)] = tile;
  }

  GameTile? tileAt(int row, int column) {
    _checkPosition(row, column);

    return _tiles[_index(row, column)];
  }

  bool moveLeft() {
    return _move((row, column) => _index(row, column));
  }

  bool moveRight() {
    return _move((row, column) => _index(row, _size - 1 - column));
  }

  bool moveUp() {
    return _move((column, row) => _index(row, column));
  }

  bool moveDown() {
    return _move((column, row) => _index(_size - 1 - row, column));
  }

  bool get hasReached2048 {
    return _tiles.any((tile) => tile?.value == 2048);
  }

  bool get hasReached4096 {
    return _tiles.any((tile) => tile?.value == 4096);
  }

  bool get hasReached8192 {
    return _tiles.any((tile) => tile?.value == 8192);
  }

  bool _move(int Function(int line, int position) indexFor) {
    var changed = false;

    _lastMergeScore = 0;
    _lastMergedValues.clear();

    for (var line = 0; line < _size; line++) {
      final values = <GameTile>[];

      for (var position = 0; position < _size; position++) {
        final tile = _tiles[indexFor(line, position)];

        if (tile != null) {
          values.add(tile);
        }
      }

      final merged = <GameTile>[];

      var position = 0;

      while (position < values.length) {
        final current = values[position];

        if (position + 1 < values.length &&
            values[position + 1].value == current.value &&
            !current.isFinal) {
          current.merge();

          merged.add(current);

          _lastMergeScore += current.value;
          _lastMergedValues.add(current.value);

          position += 2;
        } else {
          merged.add(current);

          position++;
        }
      }

      for (var target = 0; target < _size; target++) {
        final tile = target < merged.length ? merged[target] : null;

        final index = indexFor(line, target);

        if (!identical(_tiles[index], tile)) {
          changed = true;
        }

        _tiles[index] = tile;
      }
    }

    return changed;
  }

  int _index(int row, int column) {
    return row * _size + column;
  }

  void _checkPosition(int row, int column) {
    if (row < 0 || row >= _size || column < 0 || column >= _size) {
      throw RangeError(
        'Board position out of range: '
        '($row, $column)',
      );
    }
  }
}
