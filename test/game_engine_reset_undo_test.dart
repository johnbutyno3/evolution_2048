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

  test('reset clears the previous board and UNDO availability', () async {
    final engine = GameEngine(random: Random(19));
    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': 'ocean',
        'tiles': <int?>[
          2, 2, null, null,
          null, null, null, null,
          null, null, null, null,
          null, null, null, null,
        ],
        'score': 0,
        'bestScore': 0,
        'gameOver': false,
        'chapterComplete': false,
      }),
      isTrue,
    );

    expect(engine.moveLeft(), isTrue);
    expect(engine.createSaveData()['hasPreviousState'], isTrue);

    engine.reset();
    final resetSave = engine.createSaveData();

    expect(resetSave['score'], 0);
    expect(resetSave['previousBoard'], isNull);
    expect(resetSave['hasPreviousState'], isFalse);
    expect(engine.canUseTimeRewind, isFalse);

    await engine.flushLocalSave();
  });
}
