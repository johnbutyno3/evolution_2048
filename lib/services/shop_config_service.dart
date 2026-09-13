import 'package:cloud_firestore/cloud_firestore.dart';

class ShopConfigService {
  ShopConfigService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<String, dynamic> defaults = {
    'gold100Price': 99,
    'gold550Price': 499,
    'gold1200Price': 999,
    'gold2500Price': 1999,
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
    'premiumPrice': 999,
    'goldenPrice': 1999,
  };

  static Future<Map<String, dynamic>> load() async {
    try {
      final snapshot = await _db.collection('config').doc('shop').get();
      return {
        ...defaults,
        ...(snapshot.data() ?? <String, dynamic>{}),
      };
    } catch (_) {
      return Map<String, dynamic>.from(defaults);
    }
  }

  static int price(Map<String, dynamic> config, String key) {
    final value = config[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
