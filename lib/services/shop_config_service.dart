import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_backend.dart';

class ShopConfigService {
  ShopConfigService._();

  /// Safe local fallback while Supabase is not configured or reachable.
  static const Map<String, dynamic> defaults = {
    'gold300UsdPrice': '0.99',
    'gold1000UsdPrice': '2.99',
    'gold4000UsdPrice': '9.99',
    'gold10000UsdPrice': '19.99',
    'premiumUsdPrice': '2.99',
    'goldenUsdPrice': '5.99',
    'goldenUpgradeUsdPrice': '3.00',
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

  static Map<String, dynamic>? _cached;

  static Future<Map<String, dynamic>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) {
      return Map<String, dynamic>.from(_cached!);
    }

    if (!SupabaseBackend.isInitialized) {
      final config = Map<String, dynamic>.from(defaults);
      _cached ??= config;
      return Map<String, dynamic>.from(_cached!);
    }

    try {
      final remote = await SupabaseBackend.client
          .from('shop_config')
          .select('currency, products')
          .eq('id', 'global')
          .maybeSingle();

      final config = <String, dynamic>{
        ...defaults,
        ..._legacyPriceValues(remote),
        if (remote?['currency'] is String) 'currency': remote!['currency'],
        if (remote != null) 'products': remote['products'] ?? <String, dynamic>{},
      };
      _cached = config;
      return Map<String, dynamic>.from(config);
    } on PostgrestException {
      final config = Map<String, dynamic>.from(defaults);
      _cached ??= config;
      return Map<String, dynamic>.from(_cached!);
    } catch (_) {
      final config = Map<String, dynamic>.from(defaults);
      _cached ??= config;
      return Map<String, dynamic>.from(_cached!);
    }
  }

  static Map<String, dynamic> _legacyPriceValues(Map<String, dynamic>? remote) {
    final products = remote?['products'];
    if (products is! Map) return const <String, dynamic>{};

    final values = <String, dynamic>{};
    const productKeys = {
      'gold_300': 'gold300UsdPrice',
      'gold_1000': 'gold1000UsdPrice',
      'gold_4000': 'gold4000UsdPrice',
      'gold_10000': 'gold10000UsdPrice',
      'membership_premium': 'premiumUsdPrice',
      'membership_golden': 'goldenUsdPrice',
      'membership_upgrade_golden': 'goldenUpgradeUsdPrice',
      'tool_undo_1': 'undo1Price',
      'tool_undo_5': 'undo5Price',
      'tool_undo_20': 'undo20Price',
      'tool_undo_50': 'undo50Price',
      'tool_remove_1': 'remove1Price',
      'tool_remove_5': 'remove5Price',
      'tool_remove_20': 'remove20Price',
      'tool_remove_50': 'remove50Price',
      'tool_swap_1': 'swap1Price',
      'tool_swap_5': 'swap5Price',
      'tool_swap_20': 'swap20Price',
      'tool_swap_50': 'swap50Price',
      'tool_duplicate_1': 'duplicate1Price',
      'tool_duplicate_5': 'duplicate5Price',
      'tool_duplicate_20': 'duplicate20Price',
      'tool_duplicate_50': 'duplicate50Price',
    };

    for (final entry in productKeys.entries) {
      final product = products[entry.key];
      if (product is Map) {
        final value = product['priceGold'] ?? product['priceUsd'];
        if (value != null) values[entry.value] = value;
      }
    }

    return values;
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
