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

  test('current queued session binding writes SaveManager', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();

    expect(
      await SaveManager.setGameSessionIdIf('current-session', () => true),
      isTrue,
    );
    expect(SaveManager.gameSessionId, 'current-session');
  });
}
