import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:rebirth_2048/services/player_progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.initialize();
    await LifeManager.initializeLocal();
    LifeManager.enableGuestMode();
  });

  test('offline player can start, save, resume, and complete a chapter', () async {
    expect(LifeManager.hasUnlimitedLives, isFalse);
    expect(LifeManager.lifeCount, 5);
    expect(LifeManager.hasAuthoritativeState, isTrue);

    final progress = PlayerProgressService.instance;
    await progress.refresh();
    expect(progress.loadedLocally, isTrue);
    expect(progress.isChapterUnlocked(0), isTrue);

    final started = await progress.startGameSession(
      0,
      initialTiles: <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
      initialSave: <String, dynamic>{
        'chapter': 'ocean',
        'tiles': <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
        'gameOver': false,
        'chapterComplete': false,
      },
    );
    expect(started, isTrue);
    expect(LifeManager.lifeCount, 4);
    expect(await progress.waitForPendingStartSession(), isTrue);
    expect(progress.activeGameSessionId, isNotNull);

    expect(
      await progress.resumeGameSession(0),
      isTrue,
    );
    expect(LifeManager.lifeCount, 4, reason: 'resuming the same gameId must not charge another play');
    expect(
      await progress.completeChapter(
        chapterIndex: 0,
        replayLog: <String, dynamic>{'finalScore': 1234},
      ),
      isTrue,
    );

    expect(SaveManager.localUnlockedChapterIndex, 1);
    await progress.refresh();
    expect(progress.isChapterUnlocked(1), isFalse,
        reason: 'FREE remains limited to Ocean even after recording local progress');

    // Four more new gameIds consume the remaining lifetime allowance.
    for (var i = 0; i < 4; i++) {
      final created = await progress.startGameSession(
        0,
        initialTiles: <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
        initialSave: <String, dynamic>{
          'chapter': 'ocean',
          'tiles': <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
          'gameOver': false,
          'chapterComplete': false,
        },
      );
      expect(created, isTrue);
      await progress.abandonGameSession(
        sessionId: progress.activeGameSessionId,
        reason: 'TEST_END',
      );
    }
    expect(LifeManager.lifeCount, 0);
    expect(
      await progress.startGameSession(
        0,
        initialTiles: <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
        initialSave: <String, dynamic>{
          'chapter': 'ocean',
          'tiles': <dynamic>[2, 4, ...List<dynamic>.filled(14, null)],
          'gameOver': false,
          'chapterComplete': false,
        },
      ),
      isFalse,
      reason: 'the sixth new game must be blocked',
    );
    expect(LifeManager.lifeCount, 0);

    // The allowance survives a fresh manager initialization (app restart).
    await LifeManager.initializeLocal();
    expect(LifeManager.lifeCount, 0);
    expect(LifeManager.regenerationRemaining, isNull);
  });
}
