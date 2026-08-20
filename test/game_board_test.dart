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
