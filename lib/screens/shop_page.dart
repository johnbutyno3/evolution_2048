import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  Future<void> _buyLife({
    required int amount,
    required int price,
  }) async {
    await GoldManager.initialize();
    await LifeManager.initialize();

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
    required int price,
  }) async {
    await GoldManager.initialize();

    if (GoldManager.balance < price) {
      _message('Not enough Gold.');
      return;
    }

    if (!await GoldManager.spend(price)) {
      _message('Purchase failed.');
      return;
    }

    await ToolManager.addPurchasedUses(type, 1);

    if (!mounted) return;
    setState(() {});
    _message('Purchased 1 $name use.');
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text)),
      );
  }

  Future<void> _initialize() async {
    await GoldManager.initialize();
    await LifeManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
      ),
      body: FutureBuilder<void>(
        future: _initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ShopGoldCard(
                balance: GoldManager.balance,
              ),
              const SizedBox(height: 20),

              const Text(
                'Lives',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              _ShopProductCard(
                icon: Icons.favorite,
                title: '+1 Life',
                description: 'Add one additional gameplay life.',
                price: 10,
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(
                  amount: 1,
                  price: 10,
                ),
              ),

              _ShopProductCard(
                icon: Icons.favorite_border,
                title: '+5 Lives',
                description: 'Add five additional gameplay lives.',
                price: 45,
                enabled: !LifeManager.isGoldenMember,
                onBuy: () => _buyLife(
                  amount: 5,
                  price: 45,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Evolution Tools',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              _ShopToolCard(
                type: GameToolType.timeRewind,
                name: 'UNDO',
                description: 'Rewind the most recent move.',
                icon: Icons.undo,
                price: 50,
                onBuy: () => _buyTool(
                  type: GameToolType.timeRewind,
                  name: 'UNDO',
                  price: 50,
                ),
              ),

              _ShopToolCard(
                type: GameToolType.revive,
                name: 'REMOVE',
                description: 'Remove a selected life form.',
                icon: Icons.remove_circle_outline,
                price: 50,
                onBuy: () => _buyTool(
                  type: GameToolType.revive,
                  name: 'REMOVE',
                  price: 50,
                ),
              ),

              _ShopToolCard(
                type: GameToolType.positionSwap,
                name: 'SWAP',
                description: 'Swap two life-form positions.',
                icon: Icons.swap_horiz,
                price: 75,
                onBuy: () => _buyTool(
                  type: GameToolType.positionSwap,
                  name: 'SWAP',
                  price: 75,
                ),
              ),

              _ShopToolCard(
                type: GameToolType.duplicate,
                name: 'DUPLICATE',
                description: 'Duplicate a selected life form.',
                icon: Icons.copy_outlined,
                price: 100,
                onBuy: () => _buyTool(
                  type: GameToolType.duplicate,
                  name: 'DUPLICATE',
                  price: 100,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Purchased items are saved to local game data.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopGoldCard extends StatelessWidget {
  const _ShopGoldCard({
    required this.balance,
  });

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.monetization_on,
              size: 42,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Gold Balance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$balance',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.enabled,
    required this.onBuy,
  });

  final IconData icon;
  final String title;
  final String description;
  final int price;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: FilledButton.icon(
          onPressed: enabled ? onBuy : null,
          icon: const Icon(Icons.monetization_on_outlined),
          label: Text('$price'),
        ),
      ),
    );
  }
}

class _ShopToolCard extends StatelessWidget {
  const _ShopToolCard({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.onBuy,
  });

  final GameToolType type;
  final String name;
  final String description;
  final IconData icon;
  final int price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = ToolManager.savedUsesFor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(name),
        subtitle: Text(
          '$description\nOwned: $owned',
        ),
        isThreeLine: true,
        trailing: FilledButton.icon(
          onPressed: onBuy,
          icon: const Icon(Icons.monetization_on_outlined),
          label: Text('$price'),
        ),
      ),
    );
  }
}
