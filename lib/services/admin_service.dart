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
    'gold300UsdPrice': '0.99',
    'gold1000UsdPrice': '2.99',
    'gold4000UsdPrice': '9.99',
    'gold10000UsdPrice': '19.99',
    'premiumUsdPrice': '2.99',
    'goldenUsdPrice': '5.99',
    'undo1Price': 50,
    'undo5Price': 225,
    'undo20Price': 700,
    'undo50Price': 1500,
    'remove1Price': 100,
    'remove5Price': 450,
    'remove20Price': 1400,
    'remove50Price': 3000,
    'swap1Price': 200,
    'swap5Price': 900,
    'swap20Price': 2800,
    'swap50Price': 6000,
    'duplicate1Price': 500,
    'duplicate5Price': 2250,
    'duplicate20Price': 7000,
    'duplicate50Price': 15000,
  };
}
