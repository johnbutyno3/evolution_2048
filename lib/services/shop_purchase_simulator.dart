import 'package:flutter/foundation.dart';

import '../game/models/tools/game_tool.dart';
import '../game/services/gold_manager.dart';
import '../game/services/life_manager.dart';
import '../game/services/tool_manager.dart';

/// Debug-only local purchase simulator. It never calls a payment provider,
/// writes to Supabase, or creates a server-authoritative entitlement.
class ShopPurchaseSimulator {
  ShopPurchaseSimulator._();

  static void _requireDebugBuild() {
    if (!kDebugMode) {
      throw UnsupportedError('Purchase simulation is available in debug builds only.');
    }
  }

  static void simulateMembershipPurchase(String tier) {
    _requireDebugBuild();
    if (!const {'PREMIUM', 'GOLDEN'}.contains(tier)) {
      throw ArgumentError.value(tier, 'tier');
    }
    LifeManager.applySupabaseSnapshot(
      lives: 0,
      unlimited: true,
      membershipTier: tier,
      nextRegenAt: null,
    );
  }

  static void simulateGoldPurchase(int amount) {
    _requireDebugBuild();
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    GoldManager.applySupabaseBalance(GoldManager.balance + amount);
  }

  static void simulateToolPurchase(GameToolType type, int amount) {
    _requireDebugBuild();
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');

    final undo = LifeManager.isGoldenMember
        ? 0
        : ToolManager.savedUsesFor(GameToolType.timeRewind);
    final remove = ToolManager.savedUsesFor(GameToolType.revive);
    final swap = ToolManager.savedUsesFor(GameToolType.positionSwap);
    final duplicate = ToolManager.savedUsesFor(GameToolType.duplicate);

    final inventory = <String, int>{
      'UNDO': undo + (type == GameToolType.timeRewind ? amount : 0),
      'REMOVE': remove + (type == GameToolType.revive ? amount : 0),
      'SWAP': swap + (type == GameToolType.positionSwap ? amount : 0),
      'DUPLICATE': duplicate + (type == GameToolType.duplicate ? amount : 0),
    };
    ToolManager.applySupabaseInventory(inventory);
  }
}
