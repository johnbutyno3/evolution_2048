import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';
import 'package:rebirth_2048/services/session_generation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a stale refresh generation cannot commit after reset takes ownership', () {
    final ownership = SessionGeneration();
    final refreshGeneration = ownership.current;

    ownership.begin();

    expect(ownership.isCurrent(refreshGeneration), isFalse);
  });

  test('the current generation remains valid until a newer session operation begins', () {
    final ownership = SessionGeneration();
    final generation = ownership.begin();

    expect(ownership.isCurrent(generation), isTrue);

    ownership.begin();

    expect(ownership.isCurrent(generation), isFalse);
  });

  test('stale queued session binding does not write SaveManager', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    var owner = true;
    final write = SaveManager.setGameSessionIdIf('stale-session', () => owner);
    owner = false;

    expect(await write, isFalse);
    expect(SaveManager.gameSessionId, isNull);
  });

  test('saved chapter snapshot can be restored and cleared without resurrection', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    const sessionId = 'session-1234567890123456';
    await SaveManager.setGameSessionId(sessionId);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'gameSessionId': sessionId,
      'tiles': List<dynamic>.filled(16, null),
      'gameOver': false,
      'chapterComplete': false,
      'score': 24,
    });

    expect(SaveManager.loadCached(chapter: 'ocean')?['score'], 24);
    expect(SaveManager.unfinishedChapter, 'ocean');

    await SaveManager.clearChapter('ocean');

    expect(SaveManager.loadCached(chapter: 'ocean'), isNull);
    expect(SaveManager.unfinishedChapter, isNull);
  });

  test('a snapshot bound to a stale session cannot overwrite current save', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    const currentSession = 'current-session-123456';
    const staleSession = 'stale-session-1234567';
    await SaveManager.setGameSessionId(currentSession);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'gameSessionId': currentSession,
      'tiles': List<dynamic>.filled(16, null),
      'score': 100,
    });
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'gameSessionId': staleSession,
      'tiles': List<dynamic>.filled(16, null),
      'score': 1,
    });

    expect(SaveManager.loadCached(chapter: 'ocean')?['score'], 100);
  });

  test('current queued session binding writes SaveManager', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    expect(
      await SaveManager.setGameSessionIdIf('current-session', () => true),
      isTrue,
    );
    expect(SaveManager.gameSessionId, 'current-session');
  });
  test('account-scoped saves stay isolated and stale engine snapshots cannot cross accounts', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
    await SaveManager.bindAccount('account-a');

    const sessionA = 'account-a-session-123456';
    await SaveManager.setGameSessionId(sessionA);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'saveOwnerUid': 'account-a',
      'gameSessionId': sessionA,
      'tiles': List<dynamic>.filled(16, null),
      'score': 77,
    });
    expect(SaveManager.loadCached(chapter: 'ocean')?['score'], 77);

    await SaveManager.bindAccount('account-b');
    expect(SaveManager.gameSessionId, isNull);
    expect(SaveManager.loadCached(chapter: 'ocean'), isNull);

    // A delayed autosave from account A is rejected after account B takes over.
    await SaveManager.save(<String, dynamic>{
      'chapter': 'ocean',
      'saveOwnerUid': 'account-a',
      'gameSessionId': sessionA,
      'tiles': List<dynamic>.filled(16, null),
      'score': 999,
    });
    expect(SaveManager.loadCached(chapter: 'ocean'), isNull);

    await SaveManager.bindAccount('account-a');
    expect(SaveManager.gameSessionId, sessionA);
    expect(SaveManager.loadCached(chapter: 'ocean')?['score'], 77);
  });

}
