import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  SaveManager._();

  static const String _saveKeyPrefix = 'rebirth_2048_local_save_v1:';
  static const String _sessionKeyPrefix = 'rebirth_2048_game_session_id_v1:';
  static String? _accountUid;
  static bool _accountLoaded = false;
  static String? get accountUid => _accountUid;
  static String _storageAccount(String? uid) => uid == null || uid.isEmpty ? 'anonymous' : uid;
  static String _saveKeyFor(String? uid) => '$_saveKeyPrefix${_storageAccount(uid)}';
  static String _sessionKeyFor(String? uid) => '$_sessionKeyPrefix${_storageAccount(uid)}';
  static const String _onboardingKey = 'rebirth_2048_onboarding_completed_v1';
  static const String _profileNameKey = 'rebirth_2048_profile_name_v1';
  static const String _playerIdKey = 'rebirth_2048_player_id_v1';
  static const String _avatarIndexKey = 'rebirth_2048_avatar_index_v1';
  static const String _localeKey = 'rebirth_2048_locale_v1';
  static const String _vibrationEnabledKey = 'rebirth_2048_vibration_enabled_v1';
  static SharedPreferences? _preferences;
  static final ValueNotifier<String> localeCodeNotifier = ValueNotifier('en');

  static Map<String, dynamic>? _cachedSave;
  static Future<void> _saveQueue = Future<void>.value();

  static String? get gameSessionId {
    final value = _preferences?.getString(_sessionKeyFor(_accountUid));
    return value == null || value.isEmpty ? null : value;
  }

  /// Switches the active local snapshot namespace to one authenticated UID.
  /// Legacy global data is not auto-imported because its owner cannot be proven
  /// without matching its old session ID against this account's server state.
  static Future<void> bindAccount(String? uid) async {
    final normalized = uid == null || uid.isEmpty ? null : uid;
    if (_accountLoaded && _accountUid == normalized && _preferences != null) return;
    _preferences ??= await SharedPreferences.getInstance();
    _saveQueue = _saveQueue.then<void>((_) async {
      _accountUid = normalized;
      _cachedSave = _decode(_preferences!.getString(_saveKeyFor(normalized)));
      _accountLoaded = true;
    }, onError: (_, _) async {
      _accountUid = normalized;
      _cachedSave = _decode(_preferences!.getString(_saveKeyFor(normalized)));
      _accountLoaded = true;
    });
    await _saveQueue;
  }

  /// Binds the local chapter snapshot to the server-owned game session.
  /// A local board may only be resumed when this ID matches the server ID.
  static Future<void> setGameSessionId(String sessionId) async {
    final ownerUid = _accountUid;
    final id = sessionId.trim();
    if (id.isEmpty) return;
    _preferences ??= await SharedPreferences.getInstance();

    // Keep direct session-binding writes in the same queue as autosaves and
    // clears. A session ID change must not race an older queued snapshot.
    _saveQueue = _saveQueue.then<void>((_) async {
      if (_accountUid == ownerUid) await _preferences!.setString(_sessionKeyFor(ownerUid), id);
    }, onError: (_, _) async {
      if (_accountUid == ownerUid) await _preferences!.setString(_sessionKeyFor(ownerUid), id);
    });
    await _saveQueue;
  }

  /// Applies a binding only if [isOwner] is still true when the queued write
  /// reaches the serialized save operation.
  static Future<bool> setGameSessionIdIf(
    String sessionId,
    bool Function() isOwner,
  ) async {
    final ownerUid = _accountUid;
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    _preferences ??= await SharedPreferences.getInstance();

    final operation = _saveQueue.then<void>((_) async {
      if (_accountUid != ownerUid || !isOwner()) return;
      await _preferences!.setString(_sessionKeyFor(ownerUid), id);
    }, onError: (_, _) async {
      if (_accountUid != ownerUid || !isOwner()) return;
      await _preferences!.setString(_sessionKeyFor(ownerUid), id);
    });
    _saveQueue = operation;
    await operation;
    return _accountUid == ownerUid && isOwner();
  }

  static Future<void> rebindCachedGameSession({
    required String chapter,
    required String? previousSessionId,
    required String newSessionId,
  }) async {
    final ownerUid = _accountUid;
    final id = newSessionId.trim();
    if (id.isEmpty) return;
    _preferences ??= await SharedPreferences.getInstance();

    // Read and rewrite the snapshot only inside the save queue. Capturing
    // _cachedSave before waiting is unsafe: a fresh GameEngine save may still
    // be queued, and the older captured root could overwrite that new board
    // when the Firebase session response finally arrives.
    _saveQueue = _saveQueue.then(
      (_) => _accountUid == ownerUid ? _rebindCachedGameSessionNow(chapter: chapter, previousSessionId: previousSessionId, newSessionId: id, ownerUid: ownerUid) : Future<void>.value(),
      onError: (_, _) => _accountUid == ownerUid ? _rebindCachedGameSessionNow(chapter: chapter, previousSessionId: previousSessionId, newSessionId: id, ownerUid: ownerUid) : Future<void>.value(),
    );
    await _saveQueue;
  }

  static Future<void> _rebindCachedGameSessionNow({
    required String chapter,
    required String? previousSessionId,
    required String newSessionId,
    required String? ownerUid,
  }) async {
    if (_accountUid != ownerUid) return;
    final root = _cachedSave;
    if (root == null) return;
    final chapters = root['chapters'];
    if (chapters is! Map) return;
    final chapterSave = chapters[chapter];
    if (chapterSave is! Map) return;

    final currentId = chapterSave['gameSessionId'];
    if (previousSessionId != null && currentId != previousSessionId) return;

    final updatedChapter = Map<String, dynamic>.from(
      chapterSave.map((key, value) => MapEntry(key.toString(), value)),
    );
    updatedChapter['gameSessionId'] = newSessionId;

    final updatedChapters = <String, dynamic>{};
    for (final entry in chapters.entries) {
      final key = entry.key.toString();
      updatedChapters[key] = entry.value is Map
          ? Map<String, dynamic>.from(
              (entry.value as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : entry.value;
    }
    updatedChapters[chapter] = updatedChapter;

    final updatedRoot = Map<String, dynamic>.from(root);
    updatedRoot['chapters'] = updatedChapters;
    _cachedSave = updatedRoot;

    await _preferences!.setString(
      _sessionKeyFor(ownerUid),
      newSessionId,
    );
    await _preferences!.setString(_saveKeyFor(ownerUid), jsonEncode(updatedRoot));
  }

  static Future<void> clearGameSessionId() async {
    final ownerUid = _accountUid;
    _preferences ??= await SharedPreferences.getInstance();
    _saveQueue = _saveQueue.then<void>((_) async { if (_accountUid == ownerUid) await _preferences!.remove(_sessionKeyFor(ownerUid)); }, onError: (_, _) async { if (_accountUid == ownerUid) await _preferences!.remove(_sessionKeyFor(ownerUid)); });
    await _saveQueue;
  }

  /// Clears the binding only if [isOwner] is still true when queued.
  static Future<bool> clearGameSessionIdIf(bool Function() isOwner) async {
    final ownerUid = _accountUid;
    _preferences ??= await SharedPreferences.getInstance();
    final operation = _saveQueue.then<void>(
      (_) async {
        if (_accountUid == ownerUid && isOwner()) {
          await _preferences!.remove(_sessionKeyFor(ownerUid));
        }
      },
      onError: (_, _) async {
        if (_accountUid == ownerUid && isOwner()) {
          await _preferences!.remove(_sessionKeyFor(ownerUid));
        }
      },
    );
    _saveQueue = operation;
    await operation;
    return _accountUid == ownerUid && isOwner();
  }

  static Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    _accountLoaded = false;
    await bindAccount(_accountUid);
    localeCodeNotifier.value = localeCode;
  }

  static bool get vibrationEnabled {
    return _preferences?.getBool(_vibrationEnabledKey) ?? true;
  }

  static Future<void> saveVibrationEnabled(bool enabled) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setBool(_vibrationEnabledKey, enabled);
  }

  static String get localeCode {
    final value = _preferences?.getString(_localeKey);
    return value == 'zh' ? 'zh' : 'en';
  }

  static Future<void> saveLocaleCode(String code) async {
    final safeCode = code == 'zh' ? 'zh' : 'en';
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_localeKey, safeCode);
    localeCodeNotifier.value = safeCode;
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

  static String? get playerId {
    return _preferences?.getString(_playerIdKey);
  }

  static Future<void> savePlayerId(String playerId) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_playerIdKey, playerId.trim());
  }

  static int get avatarIndex {
    final value = _preferences?.getInt(_avatarIndexKey) ?? 0;
    return value.clamp(0, 53);
  }

  static Future<void> saveAvatarIndex(int index) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setInt(_avatarIndexKey, index.clamp(0, 53));
  }

  static bool get hasProfile {
    final name = profileName;
    return name != null && name.trim().isNotEmpty;
  }

  static Future<void> saveProfile({required String name}) async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_profileNameKey, name.trim());
  }

  /// Returns the chapter containing the local unfinished board, if any.
  /// Only a playable, non-game-over/non-completed snapshot counts.
  static String? get unfinishedChapter {
    final chapters = _cachedSave?['chapters'];
    if (chapters is! Map) return null;
    for (final entry in chapters.entries) {
      final chapter = entry.value;
      if (chapter is! Map) continue;
      final tiles = chapter['tiles'];
      final sessionId = chapter['gameSessionId'];
      final currentSessionId = gameSessionId;
      if (sessionId is String &&
          sessionId.isNotEmpty &&
          sessionId == currentSessionId &&
          chapter['gameOver'] != true &&
          chapter['chapterComplete'] != true &&
          tiles is List &&
          tiles.length == 16) {
        return entry.key.toString();
      }
    }
    return null;
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
            chapterSave.map((key, value) => MapEntry(key.toString(), value)),
          );

          if (!result.containsKey('toolUses') && root['toolUses'] != null) {
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
            chapterSave.map((key, value) => MapEntry(key.toString(), value)),
          );

          if (!result.containsKey('toolUses') && root['toolUses'] != null) {
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

  static Future<void> save(Map<String, dynamic> data) {
    final ownerUid = data['saveOwnerUid'] as String?;
    // All snapshot writes share one queue. Without this, the old engine's
    // queued autosave can finish after a restarted engine's save and put the
    // old board back into SharedPreferences.
    _saveQueue = _saveQueue.then(
      (_) => _saveNow(data, ownerUid),
      onError: (_, _) => _saveNow(data, ownerUid),
    );
    return _saveQueue;
  }

  static Future<void> _saveNow(Map<String, dynamic> data, String? ownerUid) async {
    _preferences ??= await SharedPreferences.getInstance();
    if (_accountUid != ownerUid) return;

    final chapter = data['chapter'];
    final snapshotSessionId = data['gameSessionId'];

    if (chapter is! String || chapter.isEmpty) {
      return;
    }

    final currentSessionId = gameSessionId;
    final snapshotHasSessionBinding =
        snapshotSessionId is String && snapshotSessionId.isNotEmpty;
    if (snapshotHasSessionBinding && snapshotSessionId != currentSessionId) {
      return;
    }
    if (!snapshotHasSessionBinding && currentSessionId != null) {
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
    await _preferences!.setString(_saveKeyFor(ownerUid), jsonEncode(root));
  }

  static Future<void> clearChapter(String chapter) async {
    final ownerUid = _accountUid;
    _preferences ??= await SharedPreferences.getInstance();

    // Clearing a finished/abandoned chapter must be serialized with pending
    // engine autosaves. Otherwise an old queued snapshot can execute after
    // this clear and resurrect the stale board in SharedPreferences.
    _saveQueue = _saveQueue.then(
      (_) => _accountUid == ownerUid ? _clearChapterNow(chapter, ownerUid) : Future<void>.value(),
      onError: (_, _) => _accountUid == ownerUid ? _clearChapterNow(chapter, ownerUid) : Future<void>.value(),
    );
    await _saveQueue;
  }

  static Future<void> _clearChapterNow(String chapter, String? ownerUid) async {
    if (_accountUid != ownerUid) return;
    final root = _cachedSave;
    if (root == null) return;

    final chapters = root['chapters'];
    if (chapters is! Map || !chapters.containsKey(chapter)) return;

    final updatedChapters = <String, dynamic>{};
    for (final entry in chapters.entries) {
      if (entry.key.toString() == chapter) continue;
      if (entry.value is Map) {
        updatedChapters[entry.key.toString()] = Map<String, dynamic>.from(
          (entry.value as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    }

    final updatedRoot = Map<String, dynamic>.from(root);
    updatedRoot['chapters'] = updatedChapters;

    if (updatedRoot['lastChapter'] == chapter) {
      if (updatedChapters.isEmpty) {
        updatedRoot.remove('lastChapter');
      } else {
        updatedRoot['lastChapter'] = updatedChapters.keys.last;
      }
    }

    _cachedSave = updatedRoot;
    await _preferences!.setString(_saveKeyFor(ownerUid), jsonEncode(updatedRoot));
  }

  static Future<void> clear() async {
    final ownerUid = _accountUid;
    _preferences ??= await SharedPreferences.getInstance();

    // Clear must be ordered after every previously queued autosave. Clearing
    // the cache before those writes finish lets them recreate stale data, and
    // removing the key outside the queue can be followed by an older write.
    _saveQueue = _saveQueue.then(
      (_) => _accountUid == ownerUid ? _clearNow(ownerUid) : Future<void>.value(),
      onError: (_, _) => _accountUid == ownerUid ? _clearNow(ownerUid) : Future<void>.value(),
    );
    await _saveQueue;
  }

  static Future<void> _clearNow(String? ownerUid) async {
    if (_accountUid != ownerUid) return;
    _cachedSave = null;
    await _preferences!.remove(_saveKeyFor(ownerUid));
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }
}
