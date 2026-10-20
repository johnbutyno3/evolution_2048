import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
  });

  test('a queued snapshot from the previous session cannot replace the current save', () async {
    const oldSession = 'old-session-123456789';
    const currentSession = 'current-session-123456';

    await SaveManager.setGameSessionId(currentSession);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'gameSessionId': currentSession,
      'tiles': <int?>[2, null, null, null, ...List<int?>.filled(12, null)],
      'score': 120,
      'gameOver': false,
      'chapterComplete': false,
    });

    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'gameSessionId': oldSession,
      'tiles': List<int?>.filled(16, null),
      'score': 1,
      'gameOver': false,
      'chapterComplete': false,
    });

    expect(SaveManager.gameSessionId, currentSession);
    expect(SaveManager.loadCached(chapter: 'ocean')?['score'], 120);
  });
  test('a delayed clear cannot erase a newer session binding', () async {
    const oldSession = 'old-session-clear-123456';
    const newSession = 'new-session-bind-123456';

    await SaveManager.setGameSessionId(oldSession);
    final bindNew = SaveManager.setGameSessionId(newSession);
    final clearOld = SaveManager.clearGameSessionId(
      expectedSessionId: oldSession,
    );

    await Future.wait<void>(<Future<void>>[bindNew, clearOld]);

    expect(SaveManager.gameSessionId, newSession);
  });

}
