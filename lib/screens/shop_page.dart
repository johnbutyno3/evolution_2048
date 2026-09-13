import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/tool_manager.dart';
import '../services/shop_config_service.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<Map<String, dynamic>> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    await GoldManager.initialize();
    return ShopConfigService.load();
  }

  int _price(Map<String, dynamic> config, String key) {
    return ShopConfigService.price(config, key);
  }

  String _usdPrice(Map<String, dynamic> config, String key) {
    return ShopConfigService.usdPrice(config, key);
  }

  Future<void> _buyTool({
    required GameToolType type,
    required String name,
    required int amount,
    required int price,
  }) async {
    if (GoldManager.balance < price) {
      _message('Not enough Gold.');
      return;
    }
    if (!await GoldManager.spend(price)) {
      _message('Purchase failed.');
      return;
    }

    await ToolManager.addPurchasedUses(type, amount);
    if (!mounted) return;
    setState(() {});
    _message('Purchased $amount $name use${amount == 1 ? '' : 's'}.');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _paymentUnavailable() {
    _message('Real-money payment is not connected yet.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load shop: ${snapshot.error}'));
          }

          final config = snapshot.data ?? ShopConfigService.defaults;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ShopGoldCard(balance: GoldManager.balance),
              const SizedBox(height: 20),

              const _ShopSectionTitle(title: 'Membership'),
              _MembershipCard(
                title: '高級會員 · Premium Member',
                description: 'No ads.',
                price: _usdPrice(config, 'premiumUsdPrice'),
                onBuy: _paymentUnavailable,
              ),
              _MembershipCard(
                title: '黃金會員 · Golden Member',
                description: 'No ads + unlimited lives.',
                price: _usdPrice(config, 'goldenUsdPrice'),
                onBuy: _paymentUnavailable,
              ),
              const SizedBox(height: 20),

              const _ShopSectionTitle(title: 'Gold'),
              const Text(
                'Real-money purchases are priced in USD. Payment is intentionally disabled until the payment backend is connected.',
              ),
              const SizedBox(height: 8),
              _GoldPackageCard(
                '300 Gold',
                _usdPrice(config, 'gold300UsdPrice'),
                _paymentUnavailable,
              ),
              _GoldPackageCard(
                '1,000 Gold',
                _usdPrice(config, 'gold1000UsdPrice'),
                _paymentUnavailable,
              ),
              _GoldPackageCard(
                '4,000 Gold',
                _usdPrice(config, 'gold4000UsdPrice'),
                _paymentUnavailable,
              ),
              _GoldPackageCard(
                '10,000 Gold',
                _usdPrice(config, 'gold10000UsdPrice'),
                _paymentUnavailable,
              ),
              const SizedBox(height: 20),

              const _ShopSectionTitle(title: 'Evolution Tools'),
              _toolPackages(
                config,
                GameToolType.timeRewind,
                'UNDO',
                Icons.undo,
                'undo',
              ),
              _toolPackages(
                config,
                GameToolType.revive,
                'REMOVE',
                Icons.remove_circle_outline,
                'remove',
              ),
              _toolPackages(
                config,
                GameToolType.positionSwap,
                'SWAP',
                Icons.swap_horiz,
                'swap',
              ),
              _toolPackages(
                config,
                GameToolType.duplicate,
                'DUPLICATE',
                Icons.copy_outlined,
                'duplicate',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolPackages(
    Map<String, dynamic> config,
    GameToolType type,
    String name,
    IconData icon,
    String key,
  ) {
    final owned = ToolManager.savedUsesFor(type);
    final prices = [
      _price(config, '${key}1Price'),
      _price(config, '${key}5Price'),
      _price(config, '${key}20Price'),
      _price(config, '${key}50Price'),
    ];
    final amounts = [1, 5, 20, 50];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name · Owned: $owned',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < amounts.length; i++)
                  FilledButton(
                    onPressed: () => _buyTool(
                      type: type,
                      name: name,
                      amount: amounts[i],
                      price: prices[i],
                    ),
                    child: Text('${amounts[i]} · ${prices[i]} Gold'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopSectionTitle extends StatelessWidget {
  const _ShopSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ShopGoldCard extends StatelessWidget {
  const _ShopGoldCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.monetization_on, size: 42),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Gold Balance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$balance',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.title,
    required this.description,
    required this.price,
    required this.onBuy,
  });

  final String title;
  final String description;
  final String price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(title),
        subtitle: Text(description),
        trailing: FilledButton(
          onPressed: onBuy,
          child: Text('\$$price / month'),
        ),
      ),
    );
  }
}

class _GoldPackageCard extends StatelessWidget {
  const _GoldPackageCard(this.title, this.price, this.onBuy);

  final String title;
  final String price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.monetization_on_outlined),
        title: Text(title),
        trailing: FilledButton(
          onPressed: onBuy,
          child: Text('\$$price'),
        ),
      ),
    );
  }
}
