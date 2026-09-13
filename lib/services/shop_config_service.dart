import 'package:cloud_firestore/cloud_firestore.dart';

class ShopConfigService {
  ShopConfigService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<String, dynamic> defaults = {
    'gold300UsdPrice': '0.99',
    'gold1000UsdPrice': '2.99',
    'gold4000UsdPrice': '9.99',
    'gold10000UsdPrice': '19.99',
    'premiumUsdPrice': '2.99',
    'goldenUsdPrice': '9.99',
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

  static String usdPrice(Map<String, dynamic> config, String key) {
    final value = config[key];
    if (value is num) return value.toStringAsFixed(2);
    return '$value';
  }
}
