import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
    await SaveManager.unbindAccountScope();
  });

  test('keeps game saves isolated between authenticated accounts', () async {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';

    await SaveManager.bindAccountScope(accountA);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': null,
      'tiles': <int>[2, 0, 0, 0],
    });
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[2, 0, 0, 0]);

    await SaveManager.bindAccountScope(accountB);
    expect(SaveManager.loadCached(chapter: 'C1'), isNull);
    await SaveManager.save(<String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': null,
      'tiles': <int>[4, 0, 0, 0],
    });

    await SaveManager.bindAccountScope(accountA);
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[2, 0, 0, 0]);

    await SaveManager.bindAccountScope(accountB);
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[4, 0, 0, 0]);
  });

  test('does not import guest saves into an authenticated account', () async {
    await SaveManager.unbindAccountScope();
    await SaveManager.save(<String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': null,
      'tiles': <int>[8, 0, 0, 0],
    });

    await SaveManager.bindAccountScope(
      '33333333-3333-4333-8333-333333333333',
    );
    expect(SaveManager.loadCached(chapter: 'C1'), isNull);
  });

  test('keeps cached profile fields isolated between accounts and guest', () async {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';

    await SaveManager.unbindAccountScope();
    await SaveManager.saveProfile(name: 'Guest');
    await SaveManager.savePlayerId('GUEST-001');
    await SaveManager.saveAvatarIndex(3);

    await SaveManager.bindAccountScope(accountA);
    expect(SaveManager.profileName, isNull);
    expect(SaveManager.playerId, isNull);
    expect(SaveManager.avatarIndex, 0);
    await SaveManager.saveProfile(name: 'Account A');
    await SaveManager.savePlayerId('ACCOUNT-A');
    await SaveManager.saveAvatarIndex(12);

    await SaveManager.bindAccountScope(accountB);
    expect(SaveManager.profileName, isNull);
    expect(SaveManager.playerId, isNull);
    expect(SaveManager.avatarIndex, 0);
    await SaveManager.saveProfile(name: 'Account B');
    await SaveManager.savePlayerId('ACCOUNT-B');
    await SaveManager.saveAvatarIndex(24);

    await SaveManager.bindAccountScope(accountA);
    expect(SaveManager.profileName, 'Account A');
    expect(SaveManager.playerId, 'ACCOUNT-A');
    expect(SaveManager.avatarIndex, 12);

    await SaveManager.unbindAccountScope();
    expect(SaveManager.profileName, 'Guest');
    expect(SaveManager.playerId, 'GUEST-001');
    expect(SaveManager.avatarIndex, 3);
  });

  test('rejects malformed account IDs', () async {
    expect(
      () => SaveManager.bindAccountScope('not-a-uuid'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
