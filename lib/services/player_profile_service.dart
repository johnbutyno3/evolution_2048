import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/services/save_manager.dart';

class PlayerProfileService {
  PlayerProfileService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static Future<String?> ensureProfile() async {
    final ref = _userRef;
    if (ref == null) return SaveManager.profileName;

    final snapshot = await ref.get();
    final data = snapshot.data();
    final name = data?['playerName'];
    final playerId = data?['playerId'];

    if (name is String && name.trim().isNotEmpty &&
        playerId is String && playerId.isNotEmpty) {
      await SaveManager.saveProfile(name: name.trim());
      return name.trim();
    }

    final newName = name is String && name.trim().isNotEmpty
        ? name.trim()
        : _generatePlayerName();
    final newId = playerId is String && playerId.isNotEmpty
        ? playerId
        : _generatePlayerId();

    await ref.set(
      {
        'playerName': newName,
        'playerId': newId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await SaveManager.saveProfile(name: newName);
    return newName;
  }

  static String _generatePlayerName() {
    const first = [
      'Ocean',
      'Sky',
      'Coral',
      'Wave',
      'River',
      'Aqua',
      'Nova',
      'Terra',
      'Luna',
      'Star',
      'Deep',
      'Reef',
    ];
    const second = [
      'Fox',
      'Wolf',
      'Otter',
      'Dolphin',
      'Shark',
      'Eagle',
      'Whale',
      'Tiger',
      'Panda',
      'Hawk',
      'Orca',
      'Bear',
    ];

    final random = Random.secure();
    final number = 1000 + random.nextInt(9000);
    return '${first[random.nextInt(first.length)]}'
        '${second[random.nextInt(second.length)]}$number';
  }

  static String _generatePlayerId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return 'RB-${List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join()}';
  }

  static Future<void> updatePlayerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 30) return;

    await SaveManager.saveProfile(name: trimmed);

    final ref = _userRef;
    if (ref == null) return;

    await ref.set(
      {
        'playerName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
