import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class CreatureCollectionService {
  static const Map<String, String> _chapterCodes = {
    'ocean': 'C1',
    'chapter1Ocean': 'C1',
    'land': 'C2',
    'chapter2Land': 'C2',
    'sky': 'C3',
    'chapter3Sky': 'C3',
    'history': 'C4',
    'chapter4History': 'C4',
    'tech': 'C5',
    'technology': 'C5',
    'chapter5Tech': 'C5',
    'universe': 'C6',
    'space': 'C6',
    'chapter6Space': 'C6',
    'chapter6Universe': 'C6',
  };

  static String normalizeChapterKey(String chapterKey) {
    return switch (_chapterCode(chapterKey)) {
      'C1' => 'ocean',
      'C2' => 'land',
      'C3' => 'sky',
      'C4' => 'history',
      'C5' => 'technology',
      _ => 'space',
    };
  }

  static String _chapterCode(String chapterKey) {
    final code = _chapterCodes[chapterKey];
    if (code == null) throw ArgumentError.value(chapterKey, 'chapterKey');
    return code;
  }

  static Future<Set<int>> loadDiscovered(String chapterKey) async {
    final client = SupabaseBackend.client;
    if (client.auth.currentUser == null) return <int>{};
    final rows = await client
        .from('creature_collection')
        .select('creature_value')
        .eq('chapter_code', _chapterCode(chapterKey));
    return rows
        .map<int>((row) => (row['creature_value'] as num).toInt())
        .toSet();
  }

  static Future<void> discover(
    String chapterKey,
    Iterable<int> values,
  ) async {
    final client = SupabaseBackend.client;
    if (client.auth.currentUser == null) return;
    final limit = switch (_chapterCode(chapterKey)) {
      'C1' => 4096,
      'C2' => 8192,
      'C3' => 16384,
      'C4' => 32768,
      'C5' => 65536,
      _ => 131072,
    };
    final valid = values.toSet().where((value) =>
        value >= 2 &&
        value <= limit &&
        (value & (value - 1)) == 0);
    for (final value in valid) {
      final response = await client.functions.invoke(
        'discover-creature',
        method: HttpMethod.post,
        body: <String, dynamic>{
          'chapterCode': _chapterCode(chapterKey),
          'value': value,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('Creature collection sync failed.');
      }
    }
  }
}
