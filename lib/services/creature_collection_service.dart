import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreatureCollectionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('progress').doc('collection');
  }

  static Future<Set<int>> loadDiscovered(String chapterKey) async {
    final ref = _ref;
    if (ref == null) return {};

    final snapshot = await ref.get();
    final data = snapshot.data();
    final values = data?[chapterKey];

    if (values is! List) return {};
    return values.whereType<num>().map((e) => e.toInt()).toSet();
  }

  static Future<void> discover(
    String chapterKey,
    Iterable<int> values,
  ) async {
    final ref = _ref;
    if (ref == null) return;

    final valid = values.toSet().toList();
    if (valid.isEmpty) return;

    await ref.set(
      {
        chapterKey: FieldValue.arrayUnion(valid),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
