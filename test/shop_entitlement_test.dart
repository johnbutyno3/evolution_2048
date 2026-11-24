import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/models/game_tile.dart';
import 'package:rebirth_2048/game/models/tools/game_tool.dart';
import 'package:rebirth_2048/game/services/gold_manager.dart';
import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/tool_manager.dart';
import 'package:rebirth_2048/services/shop_purchase_simulator.dart';

void main() {
  setUp(() {
    LifeManager.clearCachedState();
    GoldManager.clearCachedState();
    ToolManager.clearCachedInventory();
  });

  test('a validated FREE account snapshot unlocks only owned tools', () {
    LifeManager.applySupabaseSnapshot(
      lives: 5,
      unlimited: false,
      membershipTier: 'FREE',
      nextRegenAt: null,
    );
    GoldManager.applySupabaseBalance(250);
    ToolManager.applySupabaseInventory({
      'UNDO': 1,
      'REMOVE': 0,
      'SWAP': 0,
      'DUPLICATE': 0,
    });

    final manager = ToolManager(chapter: GameChapter.ocean);
    expect(LifeManager.membership, 'general');
    expect(LifeManager.lifeCount, 5);
    expect(GoldManager.balance, 250);
    expect(manager.canUse(GameToolType.timeRewind), isTrue);
    expect(manager.canUse(GameToolType.revive), isFalse);
    expect(manager.consumeLocal(GameToolType.timeRewind), isTrue);
    expect(manager.canUse(GameToolType.timeRewind), isFalse);
  });

  test('a validated PREMIUM snapshot grants unlimited lives', () {
    LifeManager.applySupabaseSnapshot(
      lives: 0,
      unlimited: true,
      membershipTier: 'PREMIUM',
      nextRegenAt: null,
    );

    expect(LifeManager.membership, 'premium');
    expect(LifeManager.lifeCount, -1);
    expect(LifeManager.optimisticConsumeLife(), isTrue);
  });

  test('a validated GOLDEN snapshot grants unlimited lives and UNDO', () {
    LifeManager.applySupabaseSnapshot(
      lives: 0,
      unlimited: true,
      membershipTier: 'GOLDEN',
      nextRegenAt: null,
    );
    ToolManager.applySupabaseInventory({
      'UNDO': 0,
      'REMOVE': 0,
      'SWAP': 0,
      'DUPLICATE': 0,
    });

    final manager = ToolManager(chapter: GameChapter.ocean);
    expect(LifeManager.membership, 'golden');
    expect(LifeManager.isGoldenMember, isTrue);
    expect(LifeManager.lifeCount, -1);
    expect(manager.canUse(GameToolType.timeRewind), isTrue);
    expect(manager.consumeLocal(GameToolType.timeRewind), isTrue);
  });

  test('debug Premium simulation unlocks unlimited lives locally', () {
    ShopPurchaseSimulator.simulateMembershipPurchase('PREMIUM');

    expect(LifeManager.membership, 'premium');
    expect(LifeManager.lifeCount, -1);
    expect(LifeManager.optimisticConsumeLife(), isTrue);
  });

  test('debug Golden simulation unlocks unlimited lives and UNDO locally', () {
    ShopPurchaseSimulator.simulateMembershipPurchase('GOLDEN');
    ToolManager.applySupabaseInventory({
      'UNDO': 0,
      'REMOVE': 0,
      'SWAP': 0,
      'DUPLICATE': 0,
    });

    final manager = ToolManager(chapter: GameChapter.ocean);
    expect(LifeManager.membership, 'golden');
    expect(manager.canUse(GameToolType.timeRewind), isTrue);
  });

  test('debug Gold and tool simulations update local cached permissions', () {
    ShopPurchaseSimulator.simulateGoldPurchase(300);
    ShopPurchaseSimulator.simulateToolPurchase(GameToolType.positionSwap, 1);
    ToolManager.applySupabaseInventory({
      'UNDO': 0,
      'REMOVE': 0,
      'SWAP': 1,
      'DUPLICATE': 0,
    });

    expect(GoldManager.balance, 100);
    final manager = ToolManager(chapter: GameChapter.sky);
    expect(manager.canUse(GameToolType.positionSwap), isTrue);
  });

  test('debug tool simulation rejects purchases without enough Gold', () {
    expect(
      () => ShopPurchaseSimulator.simulateToolPurchase(
        GameToolType.duplicate,
        1,
      ),
      throwsA(isA<StateError>()),
    );
    expect(GoldManager.balance, 0);
    expect(ToolManager.savedUsesFor(GameToolType.duplicate), 0);
  });

  test('debug tool simulation enforces the FREE single-use package limit', () {
    LifeManager.applySupabaseSnapshot(
      lives: 5,
      unlimited: false,
      membershipTier: 'FREE',
      nextRegenAt: null,
    );
    GoldManager.applySupabaseBalance(1000);

    expect(
      () => ShopPurchaseSimulator.simulateToolPurchase(
        GameToolType.timeRewind,
        5,
      ),
      throwsA(isA<StateError>()),
    );
    expect(GoldManager.balance, 1000);
    expect(ToolManager.savedUsesFor(GameToolType.timeRewind), 0);
  });

  test('zero account inventory never unlocks a purchasable tool', () {
    LifeManager.applySupabaseSnapshot(
      lives: 5,
      unlimited: false,
      membershipTier: 'FREE',
      nextRegenAt: null,
    );
    ToolManager.applySupabaseInventory({
      'UNDO': 0,
      'REMOVE': 0,
      'SWAP': 0,
      'DUPLICATE': 0,
    });

    final manager = ToolManager(chapter: GameChapter.ocean);
    expect(manager.canUse(GameToolType.timeRewind), isFalse);
    expect(manager.consumeLocal(GameToolType.timeRewind), isFalse);
  });
}
