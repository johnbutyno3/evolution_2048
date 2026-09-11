import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  SaveManager._();

  static const String _saveKey = 'rebirth_2048_local_save_v1';
  static const String _onboardingKey =
      'rebirth_2048_onboarding_completed_v1';
  static const String _profileNameKey =
      'rebirth_2048_profile_name_v1';
  static const String _avatarIndexKey =
      'rebirth_2048_avatar_index_v1';
  static const String _developerModeKey =
      'rebirth_2048_developer_mode_v1';
  static const String _developerAllChaptersKey =
      'rebirth_2048_developer_all_chapters_v1';
  static const String _developerAllToolsKey =
      'rebirth_2048_developer_all_tools_v1';
  static const String _developerUnlimitedToolsKey =
      'rebirth_2048_developer_unlimited_tools_v1';

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

  static int get avatarIndex {
    final value = _preferences?.getInt(_avatarIndexKey) ?? 0;
    return value.clamp(0, 11);
  }

  static Future<void> saveAvatarIndex(int index) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setInt(_avatarIndexKey, index.clamp(0, 11));
  }

  static bool get developerMode {
    return _preferences?.getBool(_developerModeKey) ?? false;
  }

  static Future<void> setDeveloperMode(bool enabled) async {
    _preferences ??= await SharedPreferences.getInstance();

    await _preferences!.setBool(_developerModeKey, enabled);

    if (enabled) {
      await _preferences!.setBool(_developerAllChaptersKey, true);
      await _preferences!.setBool(_developerAllToolsKey, true);
      await _preferences!.setBool(_developerUnlimitedToolsKey, true);
    } else {
      await _preferences!.setBool(_developerAllChaptersKey, false);
      await _preferences!.setBool(_developerAllToolsKey, false);
      await _preferences!.setBool(_developerUnlimitedToolsKey, false);
    }
  }

  static bool get developerAllChapters {
    return developerMode &&
        (_preferences?.getBool(_developerAllChaptersKey) ?? false);
  }

  static Future<void> setDeveloperAllChapters(bool enabled) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool(_developerAllChaptersKey, enabled);
  }

  static bool get developerAllTools {
    return developerMode &&
        (_preferences?.getBool(_developerAllToolsKey) ?? false);
  }

  static Future<void> setDeveloperAllTools(bool enabled) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool(_developerAllToolsKey, enabled);
  }

  static bool get developerUnlimitedTools {
    return developerMode &&
        (_preferences?.getBool(_developerUnlimitedToolsKey) ?? false);
  }

  static Future<void> setDeveloperUnlimitedTools(bool enabled) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool(_developerUnlimitedToolsKey, enabled);
  }

  static bool get hasProfile {
    final name = profileName;
    return name != null && name.trim().isNotEmpty;
  }

  static Future<void> saveProfile({required String name}) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_profileNameKey, name.trim());
  }

  static Map<String, dynamic>? loadCached({String? chapter}) {
    final root = _cachedSave;
    if (root == null) {
      return null;
    }

    final chapters = root['chapters'];

    if (chapters is Map) {
      if (chapter != null) {
        final chapterSave = chapters[chapter];

        if (chapterSave is Map) {
          final result = Map<String, dynamic>.from(
            chapterSave.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );

          if (!result.containsKey('toolUses') &&
              root['toolUses'] != null) {
            result['toolUses'] = root['toolUses'];
          }

          if (!result.containsKey('toolRewardsClaimed') &&
              root['toolRewardsClaimed'] != null) {
            result['toolRewardsClaimed'] = root['toolRewardsClaimed'];
          }

          return result;
        }

        return null;
      }

      final lastChapter = root['lastChapter'];

      if (lastChapter is String) {
        final chapterSave = chapters[lastChapter];

        if (chapterSave is Map) {
          final result = Map<String, dynamic>.from(
            chapterSave.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );

          if (!result.containsKey('toolUses') &&
              root['toolUses'] != null) {
            result['toolUses'] = root['toolUses'];
          }

          if (!result.containsKey('toolRewardsClaimed') &&
              root['toolRewardsClaimed'] != null) {
            result['toolRewardsClaimed'] = root['toolRewardsClaimed'];
          }

          return result;
        }
      }
    }

    return Map<String, dynamic>.from(root);
  }

  static Future<void> save(Map<String, dynamic> data) async {
    _preferences ??= await SharedPreferences.getInstance();

    final chapter = data['chapter'];

    if (chapter is! String || chapter.isEmpty) {
      return;
    }

    final root = _cachedSave == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_cachedSave!);

    final chapters = <String, dynamic>{};

    final existingChapters = root['chapters'];

    if (existingChapters is Map) {
      for (final entry in existingChapters.entries) {
        if (entry.value is Map) {
          chapters[entry.key.toString()] = Map<String, dynamic>.from(
            (entry.value as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
        }
      }
    }

    final chapterPayload = <String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      ...data,
    };

    if (!chapterPayload.containsKey('toolUses') && root['toolUses'] != null) {
      chapterPayload.remove('toolUses');
    }

    if (!chapterPayload.containsKey('toolRewardsClaimed') &&
        root['toolRewardsClaimed'] != null) {
      chapterPayload.remove('toolRewardsClaimed');
    }

    chapters[chapter] = chapterPayload;

    root['version'] = 1;
    root['savedAt'] = DateTime.now().millisecondsSinceEpoch;
    root['lastChapter'] = chapter;
    root['chapters'] = chapters;

    if (root['toolUses'] == null && data['toolUses'] != null) {
      root['toolUses'] = data['toolUses'];
    }

    if (root['toolRewardsClaimed'] == null &&
        data['toolRewardsClaimed'] != null) {
      root['toolRewardsClaimed'] = data['toolRewardsClaimed'];
    }

    _cachedSave = root;

    await _preferences!.setString(_saveKey, jsonEncode(root));
  }

  static Future<void> saveToolProgress({
    required Map<String, int> toolUses,
    required List<String> rewardsClaimed,
  }) async {
    _preferences ??= await SharedPreferences.getInstance();

    final root = _cachedSave == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_cachedSave!);

    root['version'] = 1;
    root['savedAt'] = DateTime.now().millisecondsSinceEpoch;
    root['toolUses'] = toolUses;
    root['toolRewardsClaimed'] = rewardsClaimed;

    _cachedSave = root;

    await _preferences!.setString(_saveKey, jsonEncode(root));
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
