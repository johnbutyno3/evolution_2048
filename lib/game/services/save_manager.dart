import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  SaveManager._();

  static const String _legacySaveKey = 'rebirth_2048_local_save_v1';
  static const String _legacyGameSessionIdKey = 'rebirth_2048_game_session_id_v1';
  static String? _activeAccountScope;

  // Guest data remains in the legacy namespace. Authenticated accounts each
  // receive isolated save and session keys, preventing cross-account resumes.
  static String get _saveKey => _activeAccountScope == null
      ? _legacySaveKey
      : '${_legacySaveKey}_$_activeAccountScope';
  static String get _gameSessionIdKey => _activeAccountScope == null
      ? _legacyGameSessionIdKey
      : '${_legacyGameSessionIdKey}_$_activeAccountScope';
  static String get _saveSlotAKey => '${_saveKey}_slot_a_v2';
  static String get _saveSlotBKey => '${_saveKey}_slot_b_v2';
  static String get _savePointerKey => '${_saveKey}_active_slot_v2';
  static int _activeSaveSlot = 1;
  static int _saveSequence = 0;
  static const String _onboardingKey = 'rebirth_2048_onboarding_completed_v1';
  static const String _legacyProfileNameKey = 'rebirth_2048_profile_name_v1';
  static const String _legacyPlayerIdKey = 'rebirth_2048_player_id_v1';
  static const String _legacyAvatarIndexKey = 'rebirth_2048_avatar_index_v1';
  static String get _profileNameKey => _scopedKey(_legacyProfileNameKey);
  static String get _playerIdKey => _scopedKey(_legacyPlayerIdKey);
  static String get _avatarIndexKey => _scopedKey(_legacyAvatarIndexKey);

  static String _scopedKey(String legacyKey) => _activeAccountScope == null
      ? legacyKey
      : '${legacyKey}_$_activeAccountScope';
  static const String _localeKey = 'rebirth_2048_locale_v1';
  static SharedPreferences? _preferences;
  static final ValueNotifier<String> localeCodeNotifier = ValueNotifier('en');

  static Map<String, dynamic>? _cachedSave;
  static Future<void> _saveQueue = Future<void>.value();

  static String? get gameSessionId {
    final value = _preferences?.getString(_gameSessionIdKey);
    return value == null || value.isEmpty ? null : value;
  }

  /// Binds the local chapter snapshot to the server-owned game session.
  /// A local board may only be resumed when this ID matches the server ID.
  static Future<void> setGameSessionId(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;
    _preferences ??= await SharedPreferences.getInstance();

    // Keep direct session-binding writes in the same queue as autosaves and
    // clears. A session ID change must not race an older queued snapshot.
    _saveQueue = _saveQueue.then(
      (_) => _preferences!.setString(
        _gameSessionIdKey,
        id,
      ),
      onError: (_, _) => _preferences!.setString(
        _gameSessionIdKey,
        id,
      ),
    );
    await _saveQueue;
  }

  /// Applies a binding only if [isOwner] is still true when the queued write
  /// reaches the serialized save operation.
  static Future<bool> setGameSessionIdIf(
    String sessionId,
    bool Function() isOwner,
  ) async {
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    _preferences ??= await SharedPreferences.getInstance();

    final operation = _saveQueue.then<void>(
      (_) async {
        if (!isOwner()) return;
        await _preferences!.setString(
          _gameSessionIdKey,
          id,
        );
      },
      onError: (_, _) async {
        if (!isOwner()) return;
        await _preferences!.setString(
          _gameSessionIdKey,
          id,
        );
      },
    );
    _saveQueue = operation;
    await operation;
    return isOwner();
  }

  static Future<void> rebindCachedGameSession({
    required String chapter,
    required String? previousSessionId,
    required String newSessionId,
  }) async {
    final id = newSessionId.trim();
    if (id.isEmpty) return;
    _preferences ??= await SharedPreferences.getInstance();

    // Read and rewrite the snapshot only inside the save queue. Capturing
    // _cachedSave before waiting is unsafe: a fresh GameEngine save may still
    // be queued, and the older captured root could overwrite that new board
    // when the Firebase session response finally arrives.
    _saveQueue = _saveQueue.then(
      (_) => _rebindCachedGameSessionNow(
        chapter: chapter,
        previousSessionId: previousSessionId,
        newSessionId: id,
      ),
      onError: (_, _) => _rebindCachedGameSessionNow(
        chapter: chapter,
        previousSessionId: previousSessionId,
        newSessionId: id,
      ),
    );
    await _saveQueue;
  }

  static String _checksum(String value) {
    // FNV-1a 32-bit checksum detects truncated or accidentally modified JSON.
    // It is an integrity check, not a cryptographic anti-cheat mechanism.
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Map<String, dynamic>? _readSnapshotSlot(String key, int slot) {
    final raw = _preferences?.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['formatVersion'] != 2 ||
          decoded['sequence'] is! int ||
          (decoded['sequence'] as int) <= 0 ||
          decoded['checksum'] is! String ||
          decoded['payload'] is! Map) {
        return null;
      }
      final payload = Map<String, dynamic>.from(
        (decoded['payload'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
      if (_checksum(jsonEncode(payload)) != decoded['checksum']) return null;
      return <String, dynamic>{
        'slot': slot,
        'sequence': decoded['sequence'],
        'payload': payload,
      };
    } catch (_) {
      return null;
    }
  }

  static void _loadBestSnapshotNow() {
    final slotA = _readSnapshotSlot(_saveSlotAKey, 0);
    final slotB = _readSnapshotSlot(_saveSlotBKey, 1);
    final pointer = _preferences?.getInt(_savePointerKey);

    Map<String, dynamic>? selected;
    if (pointer == 0 && slotA != null) {
      selected = slotA;
    } else if (pointer == 1 && slotB != null) {
      selected = slotB;
    } else if (slotA != null && slotB != null) {
      selected = (slotA['sequence'] as int) >= (slotB['sequence'] as int)
          ? slotA
          : slotB;
    } else {
      selected = slotA ?? slotB;
    }

    if (selected != null) {
      _activeSaveSlot = selected['slot'] as int;
      _saveSequence = selected['sequence'] as int;
      _cachedSave = selected['payload'] as Map<String, dynamic>;
      return;
    }

    // Backward-compatible recovery for installs that have not written a v2
    // snapshot yet. The first successful save migrates this data into slot A.
    _activeSaveSlot = 1;
    _saveSequence = 0;
    _cachedSave = _decode(_preferences?.getString(_saveKey));
  }

  static Future<void> _persistSnapshotNow(Map<String, dynamic> root) async {
    final nextSequence = _saveSequence + 1;
    final targetSlot = _activeSaveSlot == 0 ? 1 : 0;
    final payloadJson = jsonEncode(root);
    final envelope = jsonEncode(<String, dynamic>{
      'formatVersion': 2,
      'sequence': nextSequence,
      'checksum': _checksum(payloadJson),
      'payload': root,
    });
    final targetKey = targetSlot == 0 ? _saveSlotAKey : _saveSlotBKey;

    // Double-buffer commit: write the inactive slot completely first, then
    // switch the pointer. Until the pointer write succeeds, the previous
    // committed slot remains the recovery source.
    final wroteSlot = await _preferences!.setString(targetKey, envelope);
    if (!wroteSlot) throw StateError('Could not persist the save snapshot slot.');
    final committedPointer = await _preferences!.setInt(
      _savePointerKey,
      targetSlot,
    );
    if (!committedPointer) {
      throw StateError('Could not commit the active save snapshot pointer.');
    }

    _activeSaveSlot = targetSlot;
    _saveSequence = nextSequence;
    _cachedSave = root;
  }

  /// Selects the A/B snapshot whose chapter binding matches the server-owned
  /// active game ID. This recovers correctly if the app closes between writing
  /// a replacement board and the backend session transaction committing.
  static Future<bool> restoreSnapshotForSession({
    required String chapter,
    required String sessionId,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    _preferences ??= await SharedPreferences.getInstance();

    final operation = _saveQueue.then<bool>(
      (_) => _restoreSnapshotForSessionNow(chapter, id),
      onError: (_, _) => _restoreSnapshotForSessionNow(chapter, id),
    );
    _saveQueue = operation.then<void>(
      (_) {},
      onError: (_, _) {},
    );
    return operation;
  }

  static Future<bool> _restoreSnapshotForSessionNow(
    String chapter,
    String sessionId,
  ) async {
    final candidates = <Map<String, dynamic>>[];
    final slotA = _readSnapshotSlot(_saveSlotAKey, 0);
    final slotB = _readSnapshotSlot(_saveSlotBKey, 1);
    if (slotA != null) candidates.add(slotA);
    if (slotB != null) candidates.add(slotB);
    candidates.removeWhere((candidate) {
      final payload = candidate['payload'];
      if (payload is! Map) return true;
      final chapters = payload['chapters'];
      if (chapters is! Map) return true;
      final chapterSave = chapters[chapter];
      return chapterSave is! Map ||
          chapterSave['gameSessionId'] != sessionId ||
          chapterSave['tiles'] is! List ||
          (chapterSave['tiles'] as List).length != 16;
    });

    if (candidates.isEmpty) {
      final legacy = _decode(_preferences!.getString(_saveKey));
      final legacyChapters = legacy?['chapters'];
      final legacyChapter = legacyChapters is Map
          ? legacyChapters[chapter]
          : null;
      if (legacy == null ||
          legacyChapter is! Map ||
          legacyChapter['gameSessionId'] != sessionId ||
          legacyChapter['tiles'] is! List ||
          (legacyChapter['tiles'] as List).length != 16) {
        return false;
      }
      _cachedSave = legacy;
      _activeSaveSlot = 1;
      _saveSequence = 0;
    } else {
      candidates.sort(
        (a, b) => (b['sequence'] as int).compareTo(a['sequence'] as int),
      );
      final selected = candidates.first;
      final slot = selected['slot'] as int;
      final sequence = selected['sequence'] as int;
      final payload = selected['payload'] as Map<String, dynamic>;
      final pointerWritten = await _preferences!.setInt(_savePointerKey, slot);
      if (!pointerWritten) {
        throw StateError('Could not restore the matching game snapshot pointer.');
      }
      _activeSaveSlot = slot;
      _saveSequence = sequence;
      _cachedSave = payload;
    }

    final bindingWritten = await _preferences!.setString(_gameSessionIdKey, sessionId);
    if (!bindingWritten) {
      throw StateError('Could not restore the matching game-session binding.');
    }
    return true;
  }

  static Future<void> _rebindCachedGameSessionNow({
    required String chapter,
    required String? previousSessionId,
    required String newSessionId,
  }) async {
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
    await _preferences!.setString(
      _gameSessionIdKey,
      newSessionId,
    );
    await _persistSnapshotNow(updatedRoot);
  }

  static Future<void> clearGameSessionId() async {
    _preferences ??= await SharedPreferences.getInstance();
    _saveQueue = _saveQueue.then(
      (_) => _preferences!.remove(_gameSessionIdKey),
      onError: (_, _) => _preferences!.remove(_gameSessionIdKey),
    );
    await _saveQueue;
  }

  /// Clears the binding only if [isOwner] is still true when queued.
  static Future<bool> clearGameSessionIdIf(bool Function() isOwner) async {
    _preferences ??= await SharedPreferences.getInstance();
    final operation = _saveQueue.then<void>(
      (_) async {
        if (isOwner()) {
          await _preferences!.remove(_gameSessionIdKey);
        }
      },
      onError: (_, _) async {
        if (isOwner()) {
          await _preferences!.remove(_gameSessionIdKey);
        }
      },
    );
    _saveQueue = operation;
    await operation;
    return isOwner();
  }

  /// Switches the local game-save namespace to the authenticated Supabase user.
  /// Existing guest saves are deliberately not copied into an account scope.
  static Future<void> bindAccountScope(String userId) async {
    final id = userId.trim();
    if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(id)) {
      throw ArgumentError.value(userId, 'userId', 'Expected a UUID.');
    }
    _preferences ??= await SharedPreferences.getInstance();
    final operation = _saveQueue.then<void>(
      (_) async {
        if (_activeAccountScope == id) return;
        _activeAccountScope = id;
        _loadBestSnapshotNow();
      },
      onError: (_, _) async {
        if (_activeAccountScope == id) return;
        _activeAccountScope = id;
        _loadBestSnapshotNow();
      },
    );
    _saveQueue = operation;
    await operation;
  }

  /// Returns to the guest namespace after sign-out. Account saves remain
  /// stored under their own IDs and are never merged into guest progress.
  static Future<void> unbindAccountScope() async {
    _preferences ??= await SharedPreferences.getInstance();
    final operation = _saveQueue.then<void>(
      (_) async {
        _activeAccountScope = null;
        _loadBestSnapshotNow();
      },
      onError: (_, _) async {
        _activeAccountScope = null;
        _loadBestSnapshotNow();
      },
    );
    _saveQueue = operation;
    await operation;
  }

  static String? get activeAccountScope => _activeAccountScope;

  static Future<void> initialize() async {
    // Refresh the plugin instance on initialization. This also keeps isolated
    // test environments and platform preference reinitialization consistent.
    _preferences = await SharedPreferences.getInstance();

    _loadBestSnapshotNow();
    localeCodeNotifier.value = localeCode;
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

  /// Removes the cached profile name when the authenticated account has none.
  static Future<void> clearProfile() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.remove(_profileNameKey);
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
    // All snapshot writes share one queue. Without this, the old engine's
    // queued autosave can finish after a restarted engine's save and put the
    // old board back into SharedPreferences.
    _saveQueue = _saveQueue.then(
      (_) => _saveNow(data),
      onError: (_, _) => _saveNow(data),
    );
    return _saveQueue;
  }

  static Future<void> _saveNow(Map<String, dynamic> data) async {
    _preferences ??= await SharedPreferences.getInstance();

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

    await _persistSnapshotNow(root);
  }

  static Future<void> clearChapter(String chapter) async {
    _preferences ??= await SharedPreferences.getInstance();

    // Clearing a finished/abandoned chapter must be serialized with pending
    // engine autosaves. Otherwise an old queued snapshot can execute after
    // this clear and resurrect the stale board in SharedPreferences.
    _saveQueue = _saveQueue.then(
      (_) => _clearChapterNow(chapter),
      onError: (_, _) => _clearChapterNow(chapter),
    );
    await _saveQueue;
  }

  static Future<void> _clearChapterNow(String chapter) async {
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

    await _persistSnapshotNow(updatedRoot);
  }

  static Future<void> clear() async {
    _preferences ??= await SharedPreferences.getInstance();
    final operation = _saveQueue.then<void>(
      (_) => _clearNow(),
      onError: (_, _) => _clearNow(),
    );
    _saveQueue = operation;
    await operation;
  }

  static Future<void> _clearNow() async {
    _cachedSave = null;
    _activeSaveSlot = 1;
    _saveSequence = 0;
    await _preferences!.remove(_saveKey);
    await _preferences!.remove(_saveSlotAKey);
    await _preferences!.remove(_saveSlotBKey);
    await _preferences!.remove(_savePointerKey);
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
