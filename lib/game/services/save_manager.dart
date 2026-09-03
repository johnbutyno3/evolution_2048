import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  SaveManager._();

  static const String _saveKey = 'rebirth_2048_local_save_v1';

  static Future<void> save(Map<String, dynamic> data) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      ...data,
    };
    await preferences.setString(_saveKey, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_saveKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_saveKey);
  }
}
