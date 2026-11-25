import 'package:flutter/material.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/life_manager.dart';
import '../game/services/gold_manager.dart';
import '../game/services/tool_manager.dart';
import '../l10n/app_localizations.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    await Future.wait([
      ToolManager.refreshInventory(),
      GoldManager.refresh(),
    ]);
  }

  Future<void> _buy({
    required GameToolType type,
    required String name,
    required int amount,
  }) async {
    if (!await ToolManager.purchase(type, amount)) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message = switch (ToolManager.lastPurchaseErrorCode) {
        'UNAUTHORIZED' => l10n.paymentUnavailable,
        'INSUFFICIENT_GOLD' => l10n.insufficientGold,
        'FREE_SINGLE_TOOL_ONLY' => l10n.freeSingleToolOnly,
        'GOLDEN_UNDO_UNLIMITED' => l10n.goldenUndoUnlimited,
        'ACCOUNT_RESTRICTED' || 'MEMBERSHIP_REQUIRES_REVIEW' => l10n.accountRestricted,
        'IDEMPOTENCY_CONFLICT' => l10n.idempotencyConflict,
        'PURCHASE_SAFETY_STORAGE_UNAVAILABLE' => l10n.purchaseProtectionUnavailable,
        'INVALID_RESPONSE' => l10n.invalidPurchaseResponse,
        'NETWORK_OR_SERVER_ERROR' => l10n.purchaseVerificationFailed,
        _ => l10n.purchaseRetryOnline,
      };
      _message(message);
      return;
    }

    if (!mounted) return;

    setState(() {});
    _message(AppLocalizations.of(context)!.purchaseSuccess(amount, name));
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.tools)),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _balanceTile(),
              _tool(
                GameToolType.timeRewind,
                AppLocalizations.of(context)!.undoToolLabel,
                Icons.undo,
              ),
              _tool(
                GameToolType.revive,
                AppLocalizations.of(context)!.removeToolLabel,
                Icons.remove_circle_outline,
              ),
              _tool(
                GameToolType.positionSwap,
                AppLocalizations.of(context)!.swapToolLabel,
                Icons.swap_horiz,
              ),
              _tool(
                GameToolType.duplicate,
                AppLocalizations.of(context)!.duplicateToolLabel,
                Icons.copy_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _balanceTile() => Card(
    child: ListTile(
      leading: const Icon(Icons.monetization_on_outlined),
      title: Text(AppLocalizations.of(context)!.goldBalanceTitle),
      trailing: Text(
        '${GoldManager.balance} Gold',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _tool(
    GameToolType type,
    String name,
    IconData icon,
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
                    '$name · ${AppLocalizations.of(context)!.ownedUses(ownedLabel)}',
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
                      onPressed: () => _buy(
                        type: type,
                        name: name,
                        amount: amounts[i],
                      ),
                      child: Text(
                        '${amounts[i]} · ${ToolManager.packagePrice(type, amounts[i])} ${AppLocalizations.of(context)!.gold}',
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
