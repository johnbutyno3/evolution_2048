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

  test('a move after restore replaces the UNDO target with the restored board', () async {
    final engine = GameEngine(random: Random(11));
    final restoredBoard = <int?>[
      4, null, null, null,
      4, null, null, null,
      null, null, null, null,
      null, null, null, null,
    ];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': 'ocean',
        'tiles': restoredBoard,
        'score': 4,
        'bestScore': 4,
        'previousBoard': <int?>[
          2, 2, null, null,
          null, null, null, null,
          null, null, null, null,
          null, null, null, null,
        ],
        'previousScore': 0,
        'hasPreviousState': true,
        'gameOver': false,
        'chapterComplete': false,
      }),
      isTrue,
    );

    expect(engine.moveRight(), isTrue);

    final afterMove = engine.createSaveData();
    expect(afterMove['previousBoard'], restoredBoard);
    expect(afterMove['previousScore'], 4);
    expect(afterMove['hasPreviousState'], isTrue);

    await engine.flushLocalSave();
  });
}
