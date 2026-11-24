import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every creature in all six chapters has English and Traditional Chinese names', () {
    final source = File('lib/game/models/creature.dart').readAsStringSync();
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final chinese = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    final chapters = RegExp(
      r'// Chapter (\d) - [^\n]+([\s\S]*?)(?=// Chapter \d -|// Global)',
    ).allMatches(source);
    expect(chapters.length, 6);

    var creatureCount = 0;
    for (final chapter in chapters) {
      final chapterNumber = chapter.group(1)!;
      final block = chapter.group(2)!;
      final creatures = RegExp(
        r"value:\s*(\d+),[\s\S]*?name:\s*'[^']+'",
      ).allMatches(block);

      for (final creature in creatures) {
        final value = creature.group(1)!;
        final key = 'creatureC${chapterNumber}V$value';
        expect(english[key], isA<String>(), reason: 'Missing English $key');
        expect(chinese[key], isA<String>(), reason: 'Missing Chinese $key');
        expect((english[key] as String).trim(), isNotEmpty);
        expect((chinese[key] as String).trim(), isNotEmpty);
        creatureCount++;
      }
    }

    expect(creatureCount, 87);
  });
}
