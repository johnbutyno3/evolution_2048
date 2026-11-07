import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/services/supabase_account_service.dart';

void main() {
  Map<String, dynamic> validSnapshot({
    int avatarIndex = 0,
    int gold = 100,
    int lives = 5,
    String tier = 'FREE',
  }) => <String, dynamic>{
    'userId': 'test-user-id',
    'displayName': 'Tester',
    'avatarIndex': avatarIndex,
    'localeCode': 'en',
    'accountStatus': 'active',
    'membership': <String, dynamic>{
      'tier': tier,
      'status': 'active',
      'verifiedAt': null,
    },
    'gold': gold,
    'dailyGold': <String, dynamic>{'claimed': false},
    'lives': <String, dynamic>{
      'count': lives,
      'unlimited': tier == 'PREMIUM' || tier == 'GOLDEN',
      'nextRegenAt': null,
    },
    'tools': <String, dynamic>{
      'UNDO': 2,
      'REMOVE': 1,
      'SWAP': 0,
      'DUPLICATE': 3,
    },
    'activeGameSession': null,
    'chapterProgress': <String, dynamic>{},
    'serverTime': '2026-10-28T02:00:00.000Z',
  };

  test('requires profile setup when the authoritative name is empty', () {
    final data = validSnapshot();
    data['displayName'] = '  ';
    final snapshot = SupabaseAccountSnapshot.parse(data);

    expect(SupabaseAccountBootstrapService.requiresProfileSetup(snapshot), isTrue);
  });

  test('does not require profile setup for a valid player name', () {
    final snapshot = SupabaseAccountSnapshot.parse(validSnapshot());

    expect(SupabaseAccountBootstrapService.requiresProfileSetup(snapshot), isFalse);
  });

  test('parses validated server-owned account entitlements', () {
    final snapshot = SupabaseAccountSnapshot.parse(validSnapshot(
      avatarIndex: 17,
      gold: 240,
      lives: 4,
    ));

    expect(snapshot.userId, 'test-user-id');
    expect(snapshot.avatarIndex, 17);
    expect(snapshot.gold, 240);
    expect(snapshot.lifeCount, 4);
    expect(snapshot.membershipTier, 'FREE');
    expect(snapshot.tools['UNDO'], 2);
    expect(snapshot.serverTime.isUtc, isTrue);
  });

  test('converts Supabase stage counts into legacy tile values', () {
    final data = validSnapshot();
    data['chapterProgress'] = <String, dynamic>{
      'C1': <String, dynamic>{'highestStage': 12, 'bestScore': 1200},
      'C2': <String, dynamic>{'highestStage': 13, 'bestScore': 2400},
      'C3': <String, dynamic>{'highestStage': 0, 'bestScore': 0},
    };

    final snapshot = SupabaseAccountSnapshot.parse(data);
    expect(snapshot.legacyChapterProgress['ocean'], {
      'highestValue': 4096,
      'score': 1200,
    });
    expect(snapshot.legacyChapterProgress['land'], {
      'highestValue': 8192,
      'score': 2400,
    });
    expect(snapshot.legacyChapterProgress['sky'], {
      'highestValue': 0,
      'score': 0,
    });
  });

  test('rejects an out-of-range avatar index', () {
    expect(
      () => SupabaseAccountSnapshot.parse(validSnapshot(avatarIndex: 54)),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects negative gold instead of trusting malformed entitlements', () {
    expect(
      () => SupabaseAccountSnapshot.parse(validSnapshot(gold: -1)),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects an unknown membership tier', () {
    expect(
      () => SupabaseAccountSnapshot.parse(validSnapshot(tier: 'ADMIN')),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects membership and unlimited-life disagreement', () {
    final data = validSnapshot(tier: 'GOLDEN');
    (data['lives'] as Map<String, dynamic>)['unlimited'] = false;
    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects non-active account status in a success response', () {
    final data = validSnapshot();
    data['accountStatus'] = 'locked';
    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('accepts revoked membership only after downgrade to FREE', () {
    final data = validSnapshot(tier: 'FREE');
    (data['membership'] as Map<String, dynamic>)['status'] = 'revoked';

    final snapshot = SupabaseAccountSnapshot.parse(data);
    expect(snapshot.membershipTier, 'FREE');
    expect(snapshot.membershipStatus, 'revoked');
    expect(snapshot.unlimitedLives, isFalse);
  });

  test('rejects revoked membership with stale paid tier', () {
    final data = validSnapshot(tier: 'FREE');
    (data['membership'] as Map<String, dynamic>)['tier'] = 'GOLDEN';
    (data['membership'] as Map<String, dynamic>)['status'] = 'revoked';
    (data['lives'] as Map<String, dynamic>)['unlimited'] = true;

    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects under-review membership in a success response', () {
    final data = validSnapshot();
    (data['membership'] as Map<String, dynamic>)['status'] = 'under_review';

    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects unsupported locale values', () {
    final data = validSnapshot();
    data['localeCode'] = 'fr';
    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });

  test('rejects missing tool inventory values', () {
    final data = validSnapshot();
    (data['tools'] as Map<String, dynamic>).remove('SWAP');
    expect(
      () => SupabaseAccountSnapshot.parse(data),
      throwsA(isA<SupabaseAccountException>()),
    );
  });
}
