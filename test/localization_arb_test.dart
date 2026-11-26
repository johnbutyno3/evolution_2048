import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Traditional Chinese ARB keys and placeholders match', () {
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final chinese = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    final englishKeys = english.keys.where((key) => !key.startsWith('@')).toSet();
    final chineseKeys = chinese.keys.where((key) => !key.startsWith('@')).toSet();

    expect(chineseKeys.difference(englishKeys), isEmpty);
    expect(englishKeys.difference(chineseKeys), isEmpty);

    for (final key in englishKeys) {
      final englishPlaceholders =
          (english['@$key'] as Map<String, dynamic>?)?['placeholders'] as Map?;
      final chinesePlaceholders =
          (chinese['@$key'] as Map<String, dynamic>?)?['placeholders'] as Map?;

      expect(
        chinesePlaceholders?.keys.toSet() ?? <Object>{},
        englishPlaceholders?.keys.toSet() ?? <Object>{},
        reason: 'Placeholder names differ for $key',
      );

      for (final placeholder in englishPlaceholders?.keys ?? const <String>[]) {
        final englishType = englishPlaceholders?[placeholder]?['type'];
        final chineseType = chinesePlaceholders?[placeholder]?['type'];
        expect(
          chineseType,
          englishType,
          reason: 'Placeholder type differs for $key.$placeholder',
        );
      }
    }
  });
}
