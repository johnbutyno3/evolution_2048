import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String _generatePlayerId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return 'RB-${List.generate(
      8,
      (_) => chars[random.nextInt(chars.length)],
    ).join()}';
  }

  static Future<String?> ensureProfile() async {
    final ref = _userRef;
    if (ref == null) return SaveManager.profileName;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await ref.get();
    final data = snapshot.data() ?? <String, dynamic>{};

    var name = data['playerName'] as String?;
    var playerId = data['playerId'] as String?;
    final avatarValue = data['avatarIndex'];
    final avatarIndex = avatarValue is num
        ? avatarValue.toInt().clamp(0, 11)
        : SaveManager.avatarIndex;

    if (name == null || name.trim().isEmpty || name.trim().toLowerCase() == 'player') {
      name = await _generateUniqueName();
    } else {
      name = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    if (playerId == null || playerId.trim().isEmpty) {
      playerId = await _reserveUniquePlayerId();
    }

    final normalizedName = _normalizeName(name);
    final nameRef = _db.collection('player_names').doc(normalizedName);
    final idRef = _db.collection('player_ids').doc(playerId);

    await _db.runTransaction((transaction) async {
      final nameSnapshot = await transaction.get(nameRef);
      final existingUid = nameSnapshot.data()?['uid'];
      if (existingUid != null && existingUid != uid) {
        throw const PlayerProfileException('Player name is already in use.');
      }

      final idSnapshot = await transaction.get(idRef);
      final existingIdUid = idSnapshot.data()?['uid'];
      if (existingIdUid != null && existingIdUid != uid) {
        throw const PlayerProfileException('Player ID is already in use.');
      }

      transaction.set(nameRef, {
        'uid': uid,
        'playerName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(idRef, {
        'uid': uid,
        'playerId': playerId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(ref, {
        'playerName': name,
        'playerNameNormalized': normalizedName,
        'playerId': playerId,
        'avatarIndex': avatarIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await SaveManager.saveProfile(name: name);
    await SaveManager.saveAvatarIndex(avatarIndex);
    return name;
  }

  static Future<String> _generateUniqueName() async {
    final base = 'Rebirther';

    for (var attempt = 0; attempt < 20; attempt++) {
      final suffix = 1000 + Random.secure().nextInt(9000);
      final candidate = '$base$suffix';
      final snapshot = await _db
          .collection('player_names')
          .doc(_normalizeName(candidate))
          .get();

      if (!snapshot.exists) return candidate;
    }

    return 'Rebirther${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  static Future<String> _reserveUniquePlayerId() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = _generatePlayerId();
      final snapshot = await _db.collection('player_ids').doc(candidate).get();
      if (!snapshot.exists) return candidate;
    }

    return _generatePlayerId();
  }

  static Future<void> updatePlayerName(String name) async {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || trimmed.length > 30) {
      throw const PlayerProfileException('Player name must be 1–30 characters.');
    }

    final ref = _userRef;
    if (ref == null) {
      await SaveManager.saveProfile(name: trimmed);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final normalizedName = _normalizeName(trimmed);
    final snapshot = await ref.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final oldName = data['playerName'] as String?;
    final oldNormalizedName = data['playerNameNormalized'] as String? ??
        (oldName == null ? null : _normalizeName(oldName));
    final playerId = data['playerId'] as String?;

    if (oldNormalizedName == normalizedName) {
      await ref.set({
        'playerName': trimmed,
        'playerNameNormalized': normalizedName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await SaveManager.saveProfile(name: trimmed);
      return;
    }

    if (playerId == null || playerId.isEmpty) {
      await ensureProfile();
      return updatePlayerName(trimmed);
    }

    final newNameRef = _db.collection('player_names').doc(normalizedName);
    final oldNameRef = oldNormalizedName == null
        ? null
        : _db.collection('player_names').doc(oldNormalizedName);
    final idRef = _db.collection('player_ids').doc(playerId);

    await _db.runTransaction((transaction) async {
      final nameSnapshot = await transaction.get(newNameRef);
      final existingUid = nameSnapshot.data()?['uid'];

      if (existingUid != null && existingUid != uid) {
        throw const PlayerProfileException('Player name is already in use.');
      }

      transaction.set(newNameRef, {
        'uid': uid,
        'playerName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (oldNameRef != null && oldNormalizedName != normalizedName) {
        transaction.delete(oldNameRef);
      }

      transaction.set(idRef, {
        'uid': uid,
        'playerId': playerId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(ref, {
        'playerName': trimmed,
        'playerNameNormalized': normalizedName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await SaveManager.saveProfile(name: trimmed);
  }

  static Future<void> updateAvatarIndex(int index) async {
    final safeIndex = index.clamp(0, 11);
    await SaveManager.saveAvatarIndex(safeIndex);

    final ref = _userRef;
    if (ref == null) return;

    await ref.set({
      'avatarIndex': safeIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
