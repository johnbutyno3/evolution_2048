import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
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
    await LifeManager.initialize();
    return ShopConfigService.load();
  }

  int _price(Map<String, dynamic> config, String key) {
    return ShopConfigService.price(config, key);
  }

  Future<void> _buyLife({
    required int amount,
    required int price,
  }) async {
    if (LifeManager.isGoldenMember) {
      _message('Golden Members already have unlimited lives.');
      return;
    }
    if (GoldManager.balance < price) {
      _message('Not enough Gold.');
      return;
    }
    if (!await GoldManager.spend(price)) {
      _message('Purchase failed.');
      return;
    }

    await LifeManager.addPurchasedLives(amount);
    if (!mounted) return;
    setState(() {});
    _message('Purchased $amount life${amount == 1 ? '' : 's'}.');
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
                title: 'Premium Member',
                description: 'Membership upgrade. Benefits can be configured later.',
                price: _price(config, 'premiumPrice'),
                onBuy: _paymentUnavailable,
              ),
              _MembershipCard(
                title: 'Golden Member',
                description: 'Unlimited lives and premium membership benefits.',
                price: _price(config, 'goldenPrice'),
                onBuy: _paymentUnavailable,
              ),
              const SizedBox(height: 20),

              const _ShopSectionTitle(title: 'Gold'),
              const Text(
                'Gold packages are displayed from Firestore. Real-money payment is intentionally disabled until the payment backend is connected.',
              ),
              const SizedBox(height: 8),
              _GoldPackageCard('100 Gold', _price(config, 'gold100Price'), _paymentUnavailable),
              _GoldPackageCard('550 Gold', _price(config, 'gold550Price'), _paymentUnavailable),
              _GoldPackageCard('1,200 Gold', _price(config, 'gold1200Price'), _paymentUnavailable),
              _GoldPackageCard('2,500 Gold', _price(config, 'gold2500Price'), _paymentUnavailable),
              const SizedBox(height: 20),

              const _ShopSectionTitle(title: 'Lives'),
              _LifePackageCard(
                amount: 1,
                price: _price(config, 'life1Price'),
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(amount: 1, price: _price(config, 'life1Price')),
              ),
              _LifePackageCard(
                amount: 5,
                price: _price(config, 'life5Price'),
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(amount: 5, price: _price(config, 'life5Price')),
              ),
              _LifePackageCard(
                amount: 10,
                price: _price(config, 'life10Price'),
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(amount: 10, price: _price(config, 'life10Price')),
              ),
              _LifePackageCard(
                amount: 25,
                price: _price(config, 'life25Price'),
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(amount: 25, price: _price(config, 'life25Price')),
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
      _price(config, '${key}10Price'),
      _price(config, '${key}25Price'),
    ];
    final amounts = [1, 5, 10, 25];

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
                    child: Text('${amounts[i]} · ${prices[i]}'),
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
  final int price;
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
          child: Text('NT$ $price'),
        ),
      ),
    );
  }
}

class _GoldPackageCard extends StatelessWidget {
  const _GoldPackageCard(this.title, this.price, this.onBuy);

  final String title;
  final int price;
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
          child: Text('NT$ $price'),
        ),
      ),
    );
  }
}

class _LifePackageCard extends StatelessWidget {
  const _LifePackageCard({
    required this.amount,
    required this.price,
    required this.enabled,
    required this.onBuy,
  });

  final int amount;
  final int price;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.favorite),
        title: Text('+$amount ${amount == 1 ? 'Life' : 'Lives'}'),
        subtitle: const Text('Purchased with Gold'),
        trailing: FilledButton(
          onPressed: enabled ? onBuy : null,
          child: Text('$price Gold'),
        ),
      ),
    );
  }
}
