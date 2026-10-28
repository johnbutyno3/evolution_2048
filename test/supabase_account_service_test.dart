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
    'serverTime': '2026-10-28T02:00:00.000Z',
  };

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
