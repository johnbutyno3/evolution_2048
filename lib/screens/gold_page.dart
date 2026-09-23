import 'package:flutter/material.dart';

import '../game/services/gold_manager.dart';
import '../services/shop_config_service.dart';

class GoldPage extends StatefulWidget {
  const GoldPage({super.key});

  @override
  State<GoldPage> createState() => _GoldPageState();
}

class _GoldPageState extends State<GoldPage> {
  late Future<Map<String, dynamic>> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    return ShopConfigService.load();
  }

  void _unavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Real-money payment is not connected yet.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gold')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final config = snapshot.data ?? ShopConfigService.defaults;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monetization_on, size: 34),
                  title: const Text('Gold Balance'),
                  trailing: Text(
                    '${GoldManager.balance}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _goldPackage(
                config,
                300,
                'gold300UsdPrice',
              ),
              _goldPackage(
                config,
                1000,
                'gold1000UsdPrice',
              ),
              _goldPackage(
                config,
                4000,
                'gold4000UsdPrice',
              ),
              _goldPackage(
                config,
                10000,
                'gold10000UsdPrice',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _goldPackage(
    Map<String, dynamic> config,
    int amount,
    String priceKey,
  ) {
    final price = ShopConfigService.usdPrice(config, priceKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: const Icon(Icons.monetization_on_outlined),
        title: Text(
          '$amount Gold',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: FilledButton(
          onPressed: _unavailable,
          child: Text('\$$price'),
        ),
      ),
    );
  }
}
