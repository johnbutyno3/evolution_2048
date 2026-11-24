import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/game/models/game_tile.dart';
import 'package:rebirth_2048/game/models/tools/game_tool.dart';
import 'package:rebirth_2048/game/services/gold_manager.dart';
import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/tool_manager.dart';

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
