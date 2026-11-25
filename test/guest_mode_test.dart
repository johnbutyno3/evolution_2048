import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:rebirth_2048/services/player_progress_service.dart';
import 'package:rebirth_2048/services/supabase_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.initialize();
    LifeManager.enableGuestMode();
  });

  test('guest can start, save, resume, and complete a chapter without auth', () async {
    expect(SupabaseBackend.isAuthenticated, isFalse);
    expect(LifeManager.hasUnlimitedLives, isTrue);
    expect(LifeManager.hasAuthoritativeState, isTrue);

    final progress = PlayerProgressService.instance;
    await progress.refresh();
    expect(progress.loadedFromServer, isTrue);
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
    expect(await progress.waitForPendingStartSession(), isTrue);
    expect(progress.activeGameSessionId, isNotNull);

    expect(
      await progress.resumeGameSession(0),
      isTrue,
    );
    expect(
      await progress.completeChapter(
        chapterIndex: 0,
        replayLog: <String, dynamic>{'finalScore': 1234},
      ),
      isTrue,
    );

    expect(SaveManager.localUnlockedChapterIndex, 1);
    await progress.refresh();
    expect(progress.isChapterUnlocked(1), isTrue);
  });
}
