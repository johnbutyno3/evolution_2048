import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rebirth_2048/game/services/save_manager.dart';

const _accountId = '11111111-1111-4111-8111-111111111111';
const _accountSaveKey = 'rebirth_2048_local_save_v1_$_accountId';

Map<String, dynamic> _save(int tile) => <String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': 'session-1',
      'tiles': <int>[tile, 0, 0, 0],
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SaveManager.initialize();
    await SaveManager.bindAccountScope(_accountId);
  });

  test('writes versioned checksummed snapshots to alternating slots', () async {
    await SaveManager.setGameSessionId('session-1');
    await SaveManager.save(_save(2));

    final preferences = await SharedPreferences.getInstance();
    final slotA = preferences.getString('${_accountSaveKey}_slot_a_v2');
    expect(slotA, isNotNull);

    final first = jsonDecode(slotA!) as Map<String, dynamic>;
    expect(first['formatVersion'], 2);
    expect(first['sequence'], 1);
    expect(first['checksum'], isA<String>());
    expect(
      (first['payload'] as Map)['chapters']['C1']['tiles'],
      <int>[2, 0, 0, 0],
    );

    await SaveManager.save(_save(4));
    final slotB = preferences.getString('${_accountSaveKey}_slot_b_v2');
    expect(slotB, isNotNull);
    final second = jsonDecode(slotB!) as Map<String, dynamic>;
    expect(second['sequence'], 2);
    expect(preferences.getInt('${_accountSaveKey}_active_slot_v2'), 1);
  });

  test('falls back to the previous committed snapshot when newest slot is corrupt', () async {
    await SaveManager.setGameSessionId('session-1');
    await SaveManager.save(_save(2));
    await SaveManager.save(_save(4));

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '${_accountSaveKey}_slot_b_v2',
      '{corrupted-json',
    );

    await SaveManager.initialize();

    expect(
      SaveManager.loadCached(chapter: 'C1')?['tiles'],
      <int>[2, 0, 0, 0],
    );
  });

  test('rejects a valid JSON snapshot whose payload checksum no longer matches', () async {
    await SaveManager.setGameSessionId('session-1');
    await SaveManager.save(_save(2));
    await SaveManager.save(_save(4));

    final preferences = await SharedPreferences.getInstance();
    final key = '${_accountSaveKey}_slot_b_v2';
    final envelope = jsonDecode(preferences.getString(key)!) as Map<String, dynamic>;
    final payload = Map<String, dynamic>.from(envelope['payload'] as Map);
    final chapters = Map<String, dynamic>.from(payload['chapters'] as Map);
    final chapter = Map<String, dynamic>.from(chapters['C1'] as Map);
    chapter['tiles'] = <int>[8, 0, 0, 0];
    chapters['C1'] = chapter;
    payload['chapters'] = chapters;
    envelope['payload'] = payload;
    await preferences.setString(key, jsonEncode(envelope));

    await SaveManager.initialize();

    expect(
      SaveManager.loadCached(chapter: 'C1')?['tiles'],
      <int>[2, 0, 0, 0],
    );
  });

  test('loads the legacy single-key save and migrates it on the next write', () async {
    await SaveManager.unbindAccountScope();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _accountSaveKey,
      jsonEncode(<String, dynamic>{
        'version': 1,
        'lastChapter': 'C1',
        'chapters': <String, dynamic>{
          'C1': <String, dynamic>{
            'chapter': 'C1',
            'gameSessionId': 'session-1',
            'tiles': <int>[2, 0, 0, 0],
          },
        },
      }),
    );

    await SaveManager.bindAccountScope(_accountId);
    expect(
      SaveManager.loadCached(chapter: 'C1')?['tiles'],
      <int>[2, 0, 0, 0],
    );

    await SaveManager.save(_save(4));
    expect(
      preferences.getString('${_accountSaveKey}_slot_a_v2'),
      isNotNull,
    );
  });

  test('selects the local snapshot matching the server-owned active session', () async {
    await SaveManager.setGameSessionId('session-old');
    await SaveManager.save(<String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': 'session-old',
      'tiles': <int>[2, 0, 0, 0],
    });

    await SaveManager.setGameSessionId('session-new');
    await SaveManager.save(<String, dynamic>{
      'chapter': 'C1',
      'gameSessionId': 'session-new',
      'tiles': <int>[4, 0, 0, 0],
    });
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[4, 0, 0, 0]);

    expect(
      await SaveManager.restoreSnapshotForSession(
        chapter: 'C1',
        sessionId: 'session-old',
      ),
      isTrue,
    );
    expect(SaveManager.gameSessionId, 'session-old');
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[2, 0, 0, 0]);

    expect(
      await SaveManager.restoreSnapshotForSession(
        chapter: 'C1',
        sessionId: 'session-new',
      ),
      isTrue,
    );
    expect(SaveManager.gameSessionId, 'session-new');
    expect(SaveManager.loadCached(chapter: 'C1')?['tiles'], <int>[4, 0, 0, 0]);
  });

}
