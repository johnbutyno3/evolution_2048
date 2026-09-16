import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/save_manager.dart';

class PlayerProfileException implements Exception {
  const PlayerProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlayerProfileService {
  PlayerProfileService._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data);
      final raw = result.data;

      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }

      throw const PlayerProfileException('Invalid profile response.');
    } on FirebaseFunctionsException catch (error) {
      throw PlayerProfileException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Profile service request failed.',
      );
    } on PlayerProfileException {
      rethrow;
    } catch (_) {
      throw const PlayerProfileException('Profile service request failed.');
    }
  }

  static int _safeAvatarIndex(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 53);
    }
    return 0;
  }

  static String? _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static Future<void> updateAvatarIndex(int index) async {
    final safeIndex = index.clamp(0, 53);
    final data = await _call(
      'updatePlayerAvatar',
      <String, dynamic>{'avatarIndex': safeIndex},
    );

    final serverIndex = _safeAvatarIndex(data['avatarIndex']);
    await SaveManager.saveAvatarIndex(serverIndex);
  }

  static Future<String?> ensureProfile() async {
    final data = await _call('ensurePlayerProfile', <String, dynamic>{});

    final name = _stringValue(data, 'playerName');
    final playerId = _stringValue(data, 'playerId');
    final avatarIndex = _safeAvatarIndex(data['avatarIndex']);

    if (name != null) {
      await SaveManager.saveProfile(name: name);
    }
    if (playerId != null) {
      await SaveManager.savePlayerId(playerId);
    }
    await SaveManager.saveAvatarIndex(avatarIndex);

    return name;
  }

  static Future<bool> updatePlayerName(String name) async {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (trimmed.isEmpty ||
        trimmed.length > 30 ||
        trimmed.toUpperCase() == 'PLAYER') {
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await SaveManager.saveProfile(name: trimmed);
      return true;
    }

    final data = await _call(
      'updatePlayerProfile',
      <String, dynamic>{'playerName': trimmed},
    );

    final serverName = _stringValue(data, 'playerName');
    final playerId = _stringValue(data, 'playerId');
    final avatarIndex = _safeAvatarIndex(data['avatarIndex']);

    if (serverName == null) {
      throw const PlayerProfileException('Profile name was not returned.');
    }

    await SaveManager.saveProfile(name: serverName);
    if (playerId != null) {
      await SaveManager.savePlayerId(playerId);
    }
    await SaveManager.saveAvatarIndex(avatarIndex);

    return true;
  }
}
