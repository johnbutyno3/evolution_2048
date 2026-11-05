import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class AdminService {
  AdminService._();

  static bool get isAdmin {
    final user = SupabaseBackend.client.auth.currentUser;
    return user?.appMetadata['role'] == 'admin';
  }

  static Future<bool> checkAdmin() async {
    final user = SupabaseBackend.client.auth.currentUser;
    return user != null && user.appMetadata['role'] == 'admin';
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

  static const Map<String, (String, String)> _productFields = {
    'gold300UsdPrice': ('gold_300', 'priceUsd'),
    'gold1000UsdPrice': ('gold_1000', 'priceUsd'),
    'gold4000UsdPrice': ('gold_4000', 'priceUsd'),
    'gold10000UsdPrice': ('gold_10000', 'priceUsd'),
    'premiumUsdPrice': ('membership_premium', 'priceUsd'),
    'goldenUsdPrice': ('membership_golden', 'priceUsd'),
    'undo1Price': ('tool_undo_1', 'priceGold'),
    'undo5Price': ('tool_undo_5', 'priceGold'),
    'undo20Price': ('tool_undo_20', 'priceGold'),
    'undo50Price': ('tool_undo_50', 'priceGold'),
    'remove1Price': ('tool_remove_1', 'priceGold'),
    'remove5Price': ('tool_remove_5', 'priceGold'),
    'remove20Price': ('tool_remove_20', 'priceGold'),
    'remove50Price': ('tool_remove_50', 'priceGold'),
    'swap1Price': ('tool_swap_1', 'priceGold'),
    'swap5Price': ('tool_swap_5', 'priceGold'),
    'swap20Price': ('tool_swap_20', 'priceGold'),
    'swap50Price': ('tool_swap_50', 'priceGold'),
    'duplicate1Price': ('tool_duplicate_1', 'priceGold'),
    'duplicate5Price': ('tool_duplicate_5', 'priceGold'),
    'duplicate20Price': ('tool_duplicate_20', 'priceGold'),
    'duplicate50Price': ('tool_duplicate_50', 'priceGold'),
  };

  static Future<Map<String, dynamic>> loadShopParameters() async {
    final row = await SupabaseBackend.client
        .from('shop_config')
        .select('products')
        .eq('id', 'global')
        .single();
    final products = row['products'];
    if (products is! Map) {
      throw const FormatException('Invalid shop configuration.');
    }
    final result = Map<String, dynamic>.from(defaultShopParameters);
    for (final entry in _productFields.entries) {
      final product = products[entry.value.$1];
      if (product is Map && product[entry.value.$2] != null) {
        result[entry.key] = product[entry.value.$2];
      }
    }
    return result;
  }

  static Future<void> saveShopParameters(Map<String, dynamic> parameters) async {
    if (!await checkAdmin()) throw const AdminException('ADMIN_REQUIRED');
    final prices = <String, dynamic>{};
    for (final key in _productFields.keys) {
      final value = parameters[key];
      if (value == null) throw AdminException('MISSING_PRICE_$key');
      prices[key] = value;
    }
    final response = await SupabaseBackend.client.functions.invoke(
      'admin-update-shop-config',
      method: HttpMethod.post,
      body: {'prices': prices},
    );
    if (response.status < 200 || response.status >= 300) {
      final payload = response.data;
      final code = payload is Map && payload['error'] is String
          ? payload['error'] as String
          : 'SHOP_CONFIG_UPDATE_FAILED';
      throw AdminException(code);
    }
  }
}

class AdminException implements Exception {
  const AdminException(this.code);
  final String code;
  @override
  String toString() => code;
}
