import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, this.initialTool});

  final GameToolType? initialTool;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  void initState() {
    super.initState();
    GoldManager.initialize();
    LifeManager.initialize();

    if (widget.initialTool != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ToolPurchasePage(tool: widget.initialTool!),
          ),
        );
      });
    }
  }

  void _openTool(GameToolType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolPurchasePage(tool: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商店'),
      ),
      body: AnimatedBuilder(
        animation: _ShopRefreshNotifier.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.monetization_on_outlined,
                    size: 34,
                  ),
                  title: const Text('Gold'),
                  subtitle: Text(
                    '累計消費 ${GoldManager.lifetimeSpent} Gold',
                  ),
                  trailing: Text(
                    '${GoldManager.balance}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Gold 商品',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              const _GoldPackageTile(
                gold: 500,
                price: 'US\$1.49',
              ),
              const _GoldPackageTile(
                gold: 1000,
                price: 'US\$2.99',
              ),
              const _GoldPackageTile(
                gold: 5000,
                price: 'US\$12.99',
              ),
              const _GoldPackageTile(
                gold: 10000,
                price: 'US\$24.99',
              ),

              const SizedBox(height: 20),

              const Text(
                '工具',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              _ToolTile(
                type: GameToolType.timeRewind,
                onTap: () => _openTool(GameToolType.timeRewind),
              ),
              _ToolTile(
                type: GameToolType.revive,
                onTap: () => _openTool(GameToolType.revive),
              ),
              _ToolTile(
                type: GameToolType.positionSwap,
                onTap: () => _openTool(GameToolType.positionSwap),
              ),
              _ToolTile(
                type: GameToolType.duplicate,
                onTap: () => _openTool(GameToolType.duplicate),
              ),

              const SizedBox(height: 20),

              const Text(
                '生命',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('生命 +1'),
                  subtitle: const Text('50 Gold'),
                  trailing: FilledButton(
                    onPressed: GoldManager.balance < 50
                        ? null
                        : () async {
                            if (!await GoldManager.spend(50)) return;

                            await LifeManager.addPurchasedLives(1);
                            _ShopRefreshNotifier.instance.refresh();

                            if (mounted) {
                              setState(() {});
                            }
                          },
                    child: const Text('購買'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ToolPurchasePage extends StatefulWidget {
  const ToolPurchasePage({
    super.key,
    required this.tool,
  });

  final GameToolType tool;

  @override
  State<ToolPurchasePage> createState() => _ToolPurchasePageState();
}

class _ToolPurchasePageState extends State<ToolPurchasePage> {
  static const List<int> quantities = [1, 5, 10, 20, 50];

  int _selected = 0;

  int get _unitPrice {
    return switch (widget.tool) {
      GameToolType.timeRewind => 50,
      GameToolType.revive => 100,
      GameToolType.positionSwap => 200,
      GameToolType.duplicate => 500,
    };
  }

  int get _price {
    return _priceFor(quantities[_selected]);
  }

  String get _name {
    return switch (widget.tool) {
      GameToolType.timeRewind => 'UNDO',
      GameToolType.revive => 'REMOVE',
      GameToolType.positionSwap => 'SWAP',
      GameToolType.duplicate => 'DUPLICATE',
    };
  }

  int _priceFor(int quantity) {
    final multiplier = switch (quantity) {
      1 => 1.0,
      5 => 0.9,
      10 => 0.8,
      20 => 0.7,
      50 => 0.6,
      _ => 1.0,
    };

    return (_unitPrice * quantity * multiplier).round();
  }

  Future<void> _buy() async {
    final quantity = quantities[_selected];

    if (!await GoldManager.spend(_price)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gold 不足'),
        ),
      );
      return;
    }

    await ToolManager.addPurchasedUses(
      widget.tool,
      quantity,
    );

    _ShopRefreshNotifier.instance.refresh();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已購買 $quantity 次 $_name',
        ),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('購買 $_name'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '目前 Gold：${GoldManager.balance}',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          RadioGroup<int>(
            groupValue: _selected,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selected = value;
              });
            },
            child: Column(
              children: List.generate(
                quantities.length,
                (index) {
                  final quantity = quantities[index];
                  final selected = index == _selected;

                  return Card(
                    child: RadioListTile<int>(
                      value: index,
                      title: Text('$quantity 次'),
                      subtitle: Text(
                        '${_priceFor(quantity)} Gold',
                      ),
                      selected: selected,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: GoldManager.balance >= _price
                ? _buy
                : null,
            icon: const Icon(
              Icons.shopping_cart_outlined,
            ),
            label: Text(
              '購買 $_price Gold',
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.type,
    required this.onTap,
  });

  final GameToolType type;
  final VoidCallback onTap;

  String get name {
    return switch (type) {
      GameToolType.timeRewind => 'UNDO',
      GameToolType.revive => 'REMOVE',
      GameToolType.positionSwap => 'SWAP',
      GameToolType.duplicate => 'DUPLICATE',
    };
  }

  int get price {
    return switch (type) {
      GameToolType.timeRewind => 50,
      GameToolType.revive => 100,
      GameToolType.positionSwap => 200,
      GameToolType.duplicate => 500,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.extension_outlined,
        ),
        title: Text(name),
        subtitle: Text(
          '1 次・$price Gold',
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _GoldPackageTile extends StatelessWidget {
  const _GoldPackageTile({
    required this.gold,
    required this.price,
  });

  final int gold;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.monetization_on,
        ),
        title: Text('$gold Gold'),
        trailing: OutlinedButton(
          onPressed: null,
          child: Text(price),
        ),
        subtitle: const Text(
          '付款功能尚未連接 App Store / Google Play',
        ),
      ),
    );
  }
}

class _ShopRefreshNotifier extends ChangeNotifier {
  _ShopRefreshNotifier._();

  static final _ShopRefreshNotifier instance =
      _ShopRefreshNotifier._();

  void refresh() => notifyListeners();
}
