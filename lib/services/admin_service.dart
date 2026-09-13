import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static Future<bool> isAdmin() async {
    final ref = _userRef;
    if (ref == null) return false;

    final snapshot = await ref.get();
    return snapshot.data()?['isAdmin'] == true;
  }

  static Future<Map<String, dynamic>> loadShopParameters() async {
    final snapshot = await _db.collection('config').doc('shop').get();
    return snapshot.data() ?? defaultShopParameters;
  }

  static Future<void> saveShopParameters(
    Map<String, dynamic> parameters,
  ) async {
    await _db.collection('config').doc('shop').set(
      {
        ...parameters,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static const Map<String, dynamic> defaultShopParameters = {
    'gold100Price': '99',
    'gold550Price': '499',
    'gold1200Price': '999',
    'gold2500Price': '1999',
    'life1Price': 10,
    'life5Price': 45,
    'life10Price': 80,
    'life25Price': 180,
    'undo1Price': 50,
    'undo5Price': 225,
    'undo10Price': 400,
    'undo25Price': 850,
    'remove1Price': 50,
    'remove5Price': 225,
    'remove10Price': 400,
    'remove25Price': 850,
    'swap1Price': 75,
    'swap5Price': 340,
    'swap10Price': 600,
    'swap25Price': 1250,
    'duplicate1Price': 100,
    'duplicate5Price': 450,
    'duplicate10Price': 800,
    'duplicate25Price': 1700,
  };
}
