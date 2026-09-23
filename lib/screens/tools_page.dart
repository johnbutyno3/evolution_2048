import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';
import '../services/shop_config_service.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late Future<Map<String, dynamic>> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ToolManager.refreshInventory(),
      ShopConfigService.load(),
    ]);
    return results[1] as Map<String, dynamic>;
  }

  Future<void> _buy({
    required GameToolType type,
    required String name,
    required int amount,
  }) async {
    if (!await ToolManager.purchase(type, amount)) {
      _message('Not enough Gold or purchase failed.');
      return;
    }

    if (!mounted) return;

    setState(() {});
    _message('Purchased $amount $name use${amount == 1 ? '' : 's'}.');
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
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
              _tool(
                config,
                GameToolType.timeRewind,
                'UNDO',
                Icons.undo,
                'undo',
              ),
              _tool(
                config,
                GameToolType.revive,
                'REMOVE',
                Icons.remove_circle_outline,
                'remove',
              ),
              _tool(
                config,
                GameToolType.positionSwap,
                'SWAP',
                Icons.swap_horiz,
                'swap',
              ),
              _tool(
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

  Widget _tool(
    Map<String, dynamic> config,
    GameToolType type,
    String name,
    IconData icon,
    String key,
  ) {
    final isGoldenUndo =
        LifeManager.isGoldenMember &&
        type == GameToolType.timeRewind;

    final owned = ToolManager.savedUsesFor(type);
    final ownedLabel = isGoldenUndo ? '∞' : '$owned';

    final amounts = [1, 5, 20, 50];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name · Owned: $ownedLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isGoldenUndo)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < amounts.length; i++)
                    FilledButton(
                      onPressed: LifeManager.membership == 'general' && amounts[i] != 1
                          ? null
                          : () => _buy(
                        type: type,
                        name: name,
                        amount: amounts[i],
                      ),
                      child: Text(
                        '${amounts[i]} · ${ShopConfigService.price(config, '${key}${amounts[i]}Price')} Gold',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
