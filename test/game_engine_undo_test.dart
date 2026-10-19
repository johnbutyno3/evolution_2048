import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/game_engine.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an invalid move preserves the last successful move UNDO snapshot', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    final engine = GameEngine(random: Random(1));
    final restored = engine.restoreFromSaveData(<String, dynamic>{
      'chapter': 'ocean',
      'score': 0,
      'bestScore': 0,
      'tiles': <int>[
        8, 8, 16, 32,
        32, 64, 8, 16,
        64, 16, 32, 8,
        16, 32, 64, 32,
      ],
      'gameOver': false,
      'chapterComplete': false,
    });
    expect(restored, isTrue);

    final initialBoard = List<int?>.from(engine.createSaveData()['tiles'] as List);

    expect(engine.moveLeft(), isTrue);
    final undoAfterSuccessfulMove =
        List<int?>.from(engine.createSaveData()['previousBoard'] as List);
    expect(undoAfterSuccessfulMove, initialBoard);
    expect(engine.createSaveData()['hasPreviousState'], isTrue);

    // The board is full again after the merge spawns into its only empty cell.
    // Every column has different adjacent values, so moving up cannot change it.
    expect(engine.moveUp(), isFalse);
    final saveAfterInvalidMove = engine.createSaveData();

    expect(saveAfterInvalidMove['previousBoard'], initialBoard);
    expect(saveAfterInvalidMove['hasPreviousState'], isTrue);

    await engine.flushLocalSave();
  });
}
