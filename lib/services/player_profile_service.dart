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

  /// Ensures every authenticated player has a permanent sequential player name.
  /// Existing names are never replaced.
  static Future<String?> ensureProfile() async {
    final userRef = _userRef;
    if (userRef == null) return SaveManager.profileName;

    final existing = await userRef.get();
    final existingName = existing.data()?['playerName'];

    if (existingName is String && existingName.trim().isNotEmpty) {
      final name = existingName.trim();
      await SaveManager.saveProfile(name: name);
      return name;
    }

    final name = await _createSequentialName();

    await userRef.set(
      {
        'playerName': name,
        'playerSerial': int.tryParse(name.substring('REBIRTH-'.length)),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await SaveManager.saveProfile(name: name);
    return name;
  }

  static Future<String> _createSequentialName() async {
    final counterRef = _db.collection('system').doc('player_serial');

    final serial = await _db.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final data = snapshot.data();
      final current = data?['nextSerial'];
      final nextSerial = current is num ? current.toInt() : 1;

      transaction.set(
        counterRef,
        {
          'nextSerial': nextSerial + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return nextSerial;
    });

    return 'REBIRTH-${serial.toString().padLeft(6, '0')}';
  }

  static Future<void> updatePlayerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 30) return;

    await SaveManager.saveProfile(name: trimmed);

    final userRef = _userRef;
    if (userRef == null) return;

    await userRef.set(
      {
        'playerName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
