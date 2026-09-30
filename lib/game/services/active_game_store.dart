import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The single device-local source of truth for the one game that can be
/// resumed. It deliberately does not know about Firebase, Life, or UI.
class ActiveGameStore {
  ActiveGameStore._();

  static const _key = 'rebirth_2048_active_game_v2';
  static SharedPreferences? _prefs;

  static Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<Map<String, dynamic>?> load() async {
    await _init();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    await _init();
    await _prefs!.setString(_key, jsonEncode(data));
  }

  static Future<void> clear() async {
    await _init();
    await _prefs!.remove(_key);
  }

  static Future<void> clearForAccountSwitch() => clear();
}
