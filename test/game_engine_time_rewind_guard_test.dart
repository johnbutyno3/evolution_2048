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

  test('UNDO without a previous state does not change the board or score', () async {
    final engine = GameEngine(random: Random(29));
    final board = <int?>[
      4, null, null, null,
      null, 2, null, null,
      null, null, null, null,
      null, null, null, null,
    ];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': 'ocean',
        'tiles': board,
        'score': 12,
        'bestScore': 12,
        'previousBoard': null,
        'previousScore': 0,
        'hasPreviousState': false,
        'gameOver': false,
        'chapterComplete': false,
      }),
      isTrue,
    );

    final before = engine.createSaveData();
    expect(engine.useTimeRewind(), isFalse);

    final after = engine.createSaveData();
    expect(after['tiles'], before['tiles']);
    expect(after['score'], before['score']);
    expect(after['toolPenaltyTotal'], before['toolPenaltyTotal']);
    expect(after['hasPreviousState'], isFalse);
    await engine.flushLocalSave();
  });
}
