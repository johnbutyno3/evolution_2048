import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/game_engine.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
  });

  test('restoring a saved board preserves its one-step UNDO snapshot and score', () async {
    final engine = GameEngine(random: Random(7));
    final previousBoard = <int?>[
      2, 2, null, null,
      4, null, null, null,
      null, null, null, null,
      null, null, null, null,
    ];
    final currentBoard = <int?>[
      4, null, null, null,
      4, null, null, null,
      null, null, null, null,
      null, null, null, null,
    ];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': 'ocean',
        'tiles': currentBoard,
        'score': 4,
        'bestScore': 8,
        'previousBoard': previousBoard,
        'previousScore': 0,
        'hasPreviousState': true,
        'gameOver': false,
        'chapterComplete': false,
      }),
      isTrue,
    );

    final restored = engine.createSaveData();
    expect(restored['tiles'], currentBoard);
    expect(restored['score'], 4);
    expect(restored['previousBoard'], previousBoard);
    expect(restored['previousScore'], 0);
    expect(restored['hasPreviousState'], isTrue);

    await engine.flushLocalSave();
  });
}
