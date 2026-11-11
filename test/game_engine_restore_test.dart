import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rebirth_2048/game/services/game_engine.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
  });

  test('restoring a full board with no legal merge immediately marks Game Over', () {
    final engine = GameEngine(forceNewBoard: true);
    final tiles = <int>[2, 4, 8, 16, 4, 8, 16, 2, 8, 16, 2, 4, 16, 2, 4, 8];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': GameChapter.ocean.name,
        'tiles': tiles,
        'gameOver': false,
        'chapterComplete': false,
        'boardLifeActive': true,
      }),
      isTrue,
    );

    expect(engine.gameOver, isTrue);
    expect(engine.chapterComplete, isFalse);
    expect(engine.moveLeft(), isFalse);
    expect(engine.gameOver, isTrue);
  });

  test('restoring a full board with an available merge does not mark Game Over', () {
    final engine = GameEngine(forceNewBoard: true);
    final tiles = <int>[2, 2, 8, 16, 4, 8, 16, 2, 8, 16, 2, 4, 16, 2, 4, 8];

    expect(
      engine.restoreFromSaveData(<String, dynamic>{
        'chapter': GameChapter.ocean.name,
        'tiles': tiles,
        'gameOver': false,
        'chapterComplete': false,
        'boardLifeActive': true,
      }),
      isTrue,
    );

    expect(engine.gameOver, isFalse);
    expect(engine.moveLeft(), isTrue);
    expect(engine.gameOver, isFalse);
  });
}
