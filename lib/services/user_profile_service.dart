import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'player_profile_service.dart';

/// Legacy compatibility facade for older profile callers.
///
/// Protected profile writes are server-authoritative and must go through
/// [PlayerProfileService]. This facade intentionally contains no client-side
/// writes to the protected profile collections.
class UserProfileService {
  UserProfileService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>> get _currentUserRef {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  static Future<bool> hasProfile() async {
    final snapshot = await _currentUserRef.get();
    final data = snapshot.data();
    return snapshot.exists &&
        data != null &&
        ((data['playerName'] is String &&
                (data['playerName'] as String).trim().isNotEmpty) ||
            (data['displayName'] is String &&
                (data['displayName'] as String).trim().isNotEmpty));
  }

  static Future<String?> getDisplayName() async {
    final snapshot = await _currentUserRef.get();
    final data = snapshot.data();
    final value = data?['playerName'] ?? data?['displayName'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static String normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  static Future<bool> isNameAvailable(String name) async {
    final normalized = normalizeName(name);
    if (normalized.isEmpty) return false;

    final snapshot = await _firestore
        .collection('player_names')
        .doc(normalized)
        .get();
    return !snapshot.exists;
  }

  static Future<void> createProfile({required String displayName}) async {
    final cleanedName = displayName.trim();
    if (cleanedName.isEmpty) {
      throw StateError('Invalid display name.');
    }

    final updated = await PlayerProfileService.updatePlayerName(cleanedName);
    if (!updated) {
      throw StateError('Invalid display name.');
    }
  }
}
