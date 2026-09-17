import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreatureCollectionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const Map<String, String> _chapterKeys = {
    'ocean': 'ocean',
    'land': 'land',
    'sky': 'sky',
    'history': 'history',
    'tech': 'technology',
    'universe': 'space',
  };

  static DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('collection');
  }

  static String normalizeChapterKey(String chapterKey) {
    return _chapterKeys[chapterKey] ?? chapterKey;
  }

  static Future<Set<int>> loadDiscovered(String chapterKey) async {
    final ref = _ref;
    if (ref == null) return {};

    final snapshot = await ref.get();
    final data = snapshot.data();
    final normalizedKey = normalizeChapterKey(chapterKey);
    final values = data?[normalizedKey];

    if (values is! List) return {};
    return values.whereType<num>().map((e) => e.toInt()).toSet();
  }

  static Future<void> discover(
    String chapterKey,
    Iterable<int> values,
  ) async {
    final valid = values.toSet().where((value) {
      return value >= 2 && value <= 4096 && (value & (value - 1)) == 0;
    }).toList();

    if (valid.isEmpty || FirebaseAuth.instance.currentUser == null) return;

    final callable = _functions.httpsCallable('discoverCreature');
    final normalizedKey = normalizeChapterKey(chapterKey);

    for (final value in valid) {
      await callable.call(<String, dynamic>{
        'chapterKey': normalizedKey,
        'value': value,
      });
    }
  }
}
