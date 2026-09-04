import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  SaveManager._();

  static const String _saveKey = 'rebirth_2048_local_save_v1';
  static const String _onboardingKey = 'rebirth_2048_onboarding_completed_v1';
  static const String _profileNameKey = 'rebirth_2048_profile_name_v1';

  static SharedPreferences? _preferences;
  static Map<String, dynamic>? _cachedSave;

  static Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_saveKey);
    _cachedSave = _decode(raw);
  }

  static bool get hasCompletedOnboarding {
    return _preferences?.getBool(_onboardingKey) ?? false;
  }

  static Future<void> completeOnboarding() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool(_onboardingKey, true);
  }

  static String? get profileName {
    return _preferences?.getString(_profileNameKey);
  }

  static bool get hasProfile {
    final name = profileName;
    return name != null && name.trim().isNotEmpty;
  }

  static Future<void> saveProfile({required String name}) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_profileNameKey, name.trim());
  }

  static Map<String, dynamic>? loadCached() =>
      _cachedSave == null ? null : Map<String, dynamic>.from(_cachedSave!);

  static Future<void> save(Map<String, dynamic> data) async {
    _preferences ??= await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      ...data,
    };
    _cachedSave = payload;
    await _preferences!.setString(_saveKey, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> load() async {
    await initialize();
    return loadCached();
  }

  static Future<void> clear() async {
    _preferences ??= await SharedPreferences.getInstance();
    _cachedSave = null;
    await _preferences!.remove(_saveKey);
  }

  static Map<String, dynamic>? _decode(String? raw) {
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
}
