import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../game/services/gold_manager.dart';

class CreatureCollectionService {
  static const String _localCollectionKey = 'rebirth_2048_local_creature_collection_v1';
  static const int _totalSpeciesCount = 87;

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

  static Map<String, Set<int>> _decodeLocal(String? raw) {
    if (raw == null || raw.isEmpty) return <String, Set<int>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Set<int>>{};
      return <String, Set<int>>{
        for (final entry in decoded.entries)
          if (entry.value is List)
            entry.key.toString(): (entry.value as List)
                .whereType<num>()
                .map((value) => value.toInt())
                .where((value) => value >= 2)
                .toSet(),
      };
    } catch (_) {
      return <String, Set<int>>{};
    }
  }

  static Future<void> reconcileCollectionRewards() async {
    final preferences = await SharedPreferences.getInstance();
    final collection = _decodeLocal(preferences.getString(_localCollectionKey));
    final uniqueSpeciesCount = collection.values.fold<int>(
      0,
      (total, species) => total + species.length,
    );
    await GoldManager.awardCollectionMilestones(
      uniqueSpeciesCount: uniqueSpeciesCount,
      allSpeciesCollected: uniqueSpeciesCount >= _totalSpeciesCount,
    );
  }

  static Future<Set<int>> loadDiscovered(String chapterKey) async {
    final preferences = await SharedPreferences.getInstance();
    final collection = _decodeLocal(preferences.getString(_localCollectionKey));
    return collection[normalizeChapterKey(chapterKey)] ?? <int>{};
  }

  static Future<void> discover(
    String chapterKey,
    Iterable<int> values, {
    required String gameId,
    required Map<String, dynamic> replayLog,
  }) async {
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
    final preferences = await SharedPreferences.getInstance();
    final collection = _decodeLocal(preferences.getString(_localCollectionKey));
    final key = normalizeChapterKey(chapterKey);
    final before = collection[key] ?? <int>{};
    final after = <int>{...before, ...valid};
    collection[key] = after;

    final encoded = <String, List<int>>{
      for (final entry in collection.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    final saved = await preferences.setString(
      _localCollectionKey,
      jsonEncode(encoded),
    );
    if (!saved) throw StateError('Could not persist local creature collection.');

    // Species identity includes its chapter, because the same numeric stage
    // represents a different creature in each chapter.
    final uniqueSpeciesCount = collection.values.fold<int>(
      0,
      (total, species) => total + species.length,
    );
    await GoldManager.awardCollectionMilestones(
      uniqueSpeciesCount: uniqueSpeciesCount,
      allSpeciesCollected: uniqueSpeciesCount >= _totalSpeciesCount,
    );
  }
}
