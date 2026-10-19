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

  for (final blockedState in <String>[
    'game over',
    'chapter complete',
  ]) {
    test('UNDO is blocked when $blockedState without changing saved state', () async {
      final engine = GameEngine(random: Random(31));
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
          'gameOver': blockedState == 'game over',
          'chapterComplete': blockedState == 'chapter complete',
        }),
        isTrue,
      );

      final before = engine.createSaveData();
      expect(engine.useTimeRewind(), isFalse);

      final after = engine.createSaveData();
      expect(after['tiles'], before['tiles']);
      expect(after['score'], before['score']);
      expect(after['toolPenaltyTotal'], before['toolPenaltyTotal']);
      expect(after['previousBoard'], before['previousBoard']);
      expect(after['hasPreviousState'], before['hasPreviousState']);
      await engine.flushLocalSave();
    });
  }
}
