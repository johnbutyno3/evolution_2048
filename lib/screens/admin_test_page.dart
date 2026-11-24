import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';
import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/shop_purchase_simulator.dart';

class AdminTestPage extends StatefulWidget {
  const AdminTestPage({super.key});

  @override
  State<AdminTestPage> createState() => _AdminTestPageState();
}

class _AdminTestPageState extends State<AdminTestPage> {
  void _simulate(VoidCallback action) {
    try {
      action();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.simulatorApplied)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.purchaseFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.simulatorTitle)),
        body: Center(child: Text(l10n.simulatorDebugOnly)),
      );
    }

    return FutureBuilder<bool>(
      future: AdminService.checkAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.simulatorTitle)),
            body: Center(child: Text(l10n.adminRequired)),
          );
        }

        final lifeCount = LifeManager.lifeCount;
        final toolName = <GameToolType, String>{
          GameToolType.timeRewind: l10n.undoToolLabel,
          GameToolType.revive: l10n.removeToolLabel,
          GameToolType.positionSwap: l10n.swapToolLabel,
          GameToolType.duplicate: l10n.duplicateToolLabel,
        };

        return Scaffold(
          appBar: AppBar(title: Text(l10n.simulatorTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.simulatorNotice),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.simulatorCurrentState,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(l10n.simulatorMembership(LifeManager.membership)),
              Text(l10n.simulatorLives(lifeCount < 0 ? '∞' : lifeCount)),
              Text(l10n.simulatorGold(GoldManager.balance)),
              for (final type in GameToolType.values)
                Text(l10n.simulatorToolUses(
                  toolName[type]!,
                  ToolManager.savedUsesFor(type),
                )),
              const Divider(height: 28),
              FilledButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateMembershipPurchase('PREMIUM'),
                ),
                child: Text(l10n.simulatePremium),
              ),
              FilledButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateMembershipPurchase('GOLDEN'),
                ),
                child: Text(l10n.simulateGolden),
              ),
              FilledButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateGoldPurchase(300),
                ),
                child: Text(l10n.simulateGold),
              ),
              OutlinedButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateToolPurchase(
                    GameToolType.timeRewind,
                    1,
                  ),
                ),
                child: Text(l10n.simulateUndo),
              ),
              OutlinedButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateToolPurchase(
                    GameToolType.revive,
                    1,
                  ),
                ),
                child: Text(l10n.simulateRemove),
              ),
              OutlinedButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateToolPurchase(
                    GameToolType.positionSwap,
                    1,
                  ),
                ),
                child: Text(l10n.simulateSwap),
              ),
              OutlinedButton(
                onPressed: () => _simulate(
                  () => ShopPurchaseSimulator.simulateToolPurchase(
                    GameToolType.duplicate,
                    1,
                  ),
                ),
                child: Text(l10n.simulateDuplicate),
              ),
            ],
          ),
        );
      },
    );
  }
}
