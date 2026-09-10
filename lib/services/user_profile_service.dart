import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  UserProfileService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

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
        data['profileCompleted'] == true &&
        data['displayName'] is String &&
        (data['displayName'] as String).trim().isNotEmpty;
  }

  static Future<String?> getDisplayName() async {
    final snapshot = await _currentUserRef.get();
    final data = snapshot.data();

    final name = data?['displayName'];
    if (name is! String || name.trim().isEmpty) {
      return null;
    }

    return name.trim();
  }

  static String normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  static Future<bool> isNameAvailable(String name) async {
    final normalized = normalizeName(name);

    if (normalized.isEmpty) {
      return false;
    }

    final snapshot = await _firestore
        .collection('usernames')
        .doc(normalized)
        .get();

    return !snapshot.exists;
  }

  static Future<void> createProfile({
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    final cleanedName = displayName.trim();
    final normalized = normalizeName(cleanedName);

    if (normalized.isEmpty) {
      throw StateError('Invalid display name.');
    }

    final usernameRef =
        _firestore.collection('usernames').doc(normalized);
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final usernameSnapshot = await transaction.get(usernameRef);

      if (usernameSnapshot.exists) {
        throw StateError('username-already-in-use');
      }

      transaction.set(usernameRef, {
        'uid': user.uid,
        'displayName': cleanedName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        userRef,
        {
          'uid': user.uid,
          'displayName': cleanedName,
          'normalizedName': normalized,
          'email': user.email,
          'profileCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
