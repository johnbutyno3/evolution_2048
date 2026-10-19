import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/models/game_board.dart';
import 'package:rebirth_2048/game/models/game_tile.dart';

void main() {
  group('GameBoard', () {
    test('merges two equal tiles to the next evolution stage', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 2));
      board.setTile(0, 1, GameTile(value: 2));

      expect(board.moveLeft(), isTrue);
      expect(board.tileAt(0, 0)?.value, 4);
      expect(board.tileAt(0, 1), isNull);
    });

    test('does not merge three equal tiles twice', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 2));
      board.setTile(0, 1, GameTile(value: 2));
      board.setTile(0, 2, GameTile(value: 2));

      board.moveLeft();

      expect(board.tileAt(0, 0)?.value, 4);
      expect(board.tileAt(0, 1)?.value, 2);
      expect(board.tileAt(0, 2), isNull);
    });

    test('merges down from the bottom of each column', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 4));
      board.setTile(1, 0, GameTile(value: 4));

      expect(board.moveDown(), isTrue);
      expect(board.tileAt(3, 0)?.value, 8);
      expect(board.tileAt(2, 0), isNull);
    });

    test('4096 is the final stage and is not merged further', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 4096));
      board.setTile(0, 1, GameTile(value: 4096));

      board.moveLeft();

      expect(board.tileAt(0, 0)?.value, 4096);
      expect(board.tileAt(0, 1)?.value, 4096);
    });


    test('moves tiles right and up without changing their values', () {
      final rightBoard = GameBoard();
      rightBoard.setTile(0, 0, GameTile(value: 2));
      expect(rightBoard.moveRight(), isTrue);
      expect(rightBoard.tileAt(0, 3)?.value, 2);
      expect(rightBoard.tileAt(0, 0), isNull);

      final upBoard = GameBoard();
      upBoard.setTile(3, 2, GameTile(value: 4));
      expect(upBoard.moveUp(), isTrue);
      expect(upBoard.tileAt(0, 2)?.value, 4);
      expect(upBoard.tileAt(3, 2), isNull);
    });

    test('returns false when a move cannot change the board', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 2));

      expect(board.moveLeft(), isFalse);
      expect(board.tileAt(0, 0)?.value, 2);
      expect(board.emptyPositions, hasLength(15));
    });

    test('reports a full board and reset clears merge metadata', () {
      final board = GameBoard();
      for (var row = 0; row < 4; row++) {
        for (var column = 0; column < 4; column++) {
          board.setTile(row, column, GameTile(value: 2));
        }
      }

      expect(board.isFull, isTrue);
      expect(board.emptyPositions, isEmpty);

      expect(board.moveLeft(), isTrue);
      expect(board.lastMergeScore, greaterThan(0));
      expect(board.lastMergedValues, isNotEmpty);

      board.reset();

      expect(board.isFull, isFalse);
      expect(board.emptyPositions, hasLength(16));
      expect(board.lastMergeScore, 0);
      expect(board.lastMergedValues, isEmpty);
      expect(board.tiles.every((tile) => tile == null), isTrue);
    });

    test('does not allow equal final-stage tiles to merge or count as a merge', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 4096));
      board.setTile(0, 1, GameTile(value: 4096));

      expect(board.hasAvailableMerge, isFalse);
      expect(board.moveLeft(), isFalse);
      expect(board.lastMergeScore, 0);
      expect(board.lastMergedValues, isEmpty);
    });

    test('reports 2048 and 4096 milestones', () {
      final board = GameBoard();
      board.setTile(0, 0, GameTile(value: 2048));
      expect(board.hasReached2048, isTrue);
      expect(board.hasReached4096, isFalse);

      board.setTile(0, 1, GameTile(value: 4096));
      expect(board.hasReached4096, isTrue);
    });
  });
}
