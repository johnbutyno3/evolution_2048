import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/game_engine.dart';
import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
    LifeManager.applyServerState(<String, dynamic>{
      'lives': -1,
      'infiniteLives': true,
      'membership': 'golden',
      'lifeMode': 'golden',
      'nextLifeAtMillis': null,
    });
  });

  tearDown(() {
    LifeManager.clearCachedState();
  });

  test('UNDO restores the previous board and applies the score penalty', () async {
    final engine = GameEngine(random: Random(23));
    final previousBoard = <int?>[
      2, 2, null, null,
      null, null, null, null,
      null, null, null, null,
      null, null, null, null,
    ];
    final currentBoard = <int?>[
      4, null, null, null,
      null, null, null, null,
      null, null, null, null,
      null, null, null, null,
    ];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': 'ocean',
        'tiles': currentBoard,
        'score': 8,
        'bestScore': 8,
        'previousBoard': previousBoard,
        'previousScore': 4,
        'hasPreviousState': true,
        'gameOver': false,
        'chapterComplete': false,
      }),
      isTrue,
    );

    expect(engine.useTimeRewind(), isTrue);

    final afterUndo = engine.createSaveData();
    expect(afterUndo['tiles'], previousBoard);
    expect(afterUndo['score'], 0);
    expect(afterUndo['toolPenaltyTotal'], 4);
    expect(afterUndo['previousBoard'], isNull);
    expect(afterUndo['hasPreviousState'], isFalse);

    await engine.flushLocalSave();
  });
}
