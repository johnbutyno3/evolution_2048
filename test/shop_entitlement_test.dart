import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebirth_2048/game/models/tools/game_tool.dart';
import 'package:rebirth_2048/game/models/game_tile.dart';
import 'package:rebirth_2048/game/services/gold_manager.dart';
import 'package:rebirth_2048/game/services/life_manager.dart';
import 'package:rebirth_2048/game/services/tool_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LifeManager.initializeLocal();
    await GoldManager.initializeLocal();
    ToolManager.clearCachedInventory();
  });

  test('FREE starts with five permanent new-game starts and no regeneration', () {
    expect(LifeManager.lifeCount, 5);
    expect(LifeManager.hasUnlimitedLives, isFalse);
    expect(LifeManager.regenerationRemaining, isNull);
    expect(LifeManager.optimisticConsumeLife(), isTrue,
        reason: 'preflight checks availability without charging twice');
    expect(LifeManager.lifeCount, 5);
  });

  test('local Gold reward is idempotent and persists', () async {
    expect(
      await GoldManager.awardOnce(rewardId: 'test:first', amount: 300),
      isTrue,
    );
    expect(
      await GoldManager.awardOnce(rewardId: 'test:first', amount: 300),
      isFalse,
    );
    expect(GoldManager.balance, 300);

    await GoldManager.initializeLocal();
    expect(GoldManager.balance, 300);
    expect(GoldManager.claimedRewardIds, contains('test:first'));
  });

  test('local tool package purchases use confirmed Gold prices', () async {
    await GoldManager.awardOnce(rewardId: 'test:seed-wallet', amount: 1000);
    final manager = ToolManager(chapter: GameChapter.ocean);

    expect(ToolManager.packagePrice(GameToolType.timeRewind, 1), 50);
    expect(ToolManager.packagePrice(GameToolType.timeRewind, 5), 225);
    expect(ToolManager.packagePrice(GameToolType.timeRewind, 20), 700);
    expect(ToolManager.packagePrice(GameToolType.timeRewind, 50), 1500);

    expect(await ToolManager.purchase(GameToolType.timeRewind, 5), isTrue);
    expect(GoldManager.balance, 775);
    expect(ToolManager.savedUsesFor(GameToolType.timeRewind), 5);
    expect(manager.canUse(GameToolType.timeRewind), isTrue);

    expect(manager.consumeLocal(GameToolType.timeRewind), isTrue);
    expect(ToolManager.savedUsesFor(GameToolType.timeRewind), 4);

    await GoldManager.flushLocalChanges();
    await GoldManager.initializeLocal();
    expect(GoldManager.balance, 775);
    expect(GoldManager.toolUses('UNDO'), 4);
  });

  test('completed games grant Gold once and cumulative milestones are permanent', () async {
    final first = await GoldManager.settleGame(
      gameId: 'game-1',
      effectiveScore: 10500,
      newSpeciesCount: 3,
      highestValue: 131072,
    );
    expect(first, 223,
        reason: '23 per-game Gold + 50 score milestone + 50 single-game achievement + 100 highest-species achievement');
    expect(GoldManager.balance, 223);
    expect(GoldManager.cumulativeScore, 10500);

    expect(
      await GoldManager.settleGame(
        gameId: 'game-1',
        effectiveScore: 10500,
        newSpeciesCount: 3,
        highestValue: 131072,
      ),
      0,
      reason: 'the same gameId must never pay twice',
    );
    expect(GoldManager.balance, 223);

    await GoldManager.flushLocalChanges();
    await GoldManager.initializeLocal();
    expect(GoldManager.balance, 223);
    expect(GoldManager.settledGameIds, contains('game-1'));
  });

  test('chapter and collection milestones are each granted only once', () async {
    expect(await GoldManager.awardChapterCompletion(0), 200);
    expect(await GoldManager.awardChapterCompletion(0), 0);
    expect(
      await GoldManager.awardCollectionMilestones(
        uniqueSpeciesCount: 25,
        allSpeciesCollected: false,
      ),
      150,
    );
    expect(
      await GoldManager.awardCollectionMilestones(
        uniqueSpeciesCount: 25,
        allSpeciesCollected: false,
      ),
      0,
    );
    expect(GoldManager.balance, 350);
  });

  test('tool package purchase is rejected without enough Gold', () async {
    expect(await ToolManager.purchase(GameToolType.duplicate, 1), isFalse);
    expect(GoldManager.balance, 0);
    expect(ToolManager.savedUsesFor(GameToolType.duplicate), 0);
  });

  test('tool availability follows chapter rules without membership tiers', () async {
    await GoldManager.awardOnce(rewardId: 'test:seed-tools', amount: 10000);
    expect(await ToolManager.purchase(GameToolType.revive, 5), isTrue);
    expect(await ToolManager.purchase(GameToolType.positionSwap, 5), isTrue);
    expect(await ToolManager.purchase(GameToolType.duplicate, 5), isTrue);

    final ocean = ToolManager(chapter: GameChapter.ocean);
    final land = ToolManager(chapter: GameChapter.land);
    final sky = ToolManager(chapter: GameChapter.sky);
    final history = ToolManager(chapter: GameChapter.history);

    expect(ocean.getTool(GameToolType.revive), isNull);
    expect(land.getTool(GameToolType.revive), isNotNull);
    expect(land.getTool(GameToolType.positionSwap), isNull);
    expect(sky.getTool(GameToolType.positionSwap), isNotNull);
    expect(sky.getTool(GameToolType.duplicate), isNull);
    expect(history.getTool(GameToolType.duplicate), isNotNull);
  });

  test('concurrent Gold rewards and game settlement cannot double-credit', () async {
    final duplicateRewards = await Future.wait<bool>([
      GoldManager.awardOnce(rewardId: 'concurrent:once', amount: 75),
      GoldManager.awardOnce(rewardId: 'concurrent:once', amount: 75),
    ]);
    expect(duplicateRewards.where((value) => value).length, 1);
    expect(GoldManager.balance, 75);

    final distinctRewards = await Future.wait<bool>([
      GoldManager.awardOnce(rewardId: 'concurrent:a', amount: 25),
      GoldManager.awardOnce(rewardId: 'concurrent:b', amount: 30),
    ]);
    expect(distinctRewards, everyElement(isTrue));
    expect(GoldManager.balance, 130);

    final duplicateSettlements = await Future.wait<int>([
      GoldManager.settleGame(
        gameId: 'concurrent-game',
        effectiveScore: 2000,
        newSpeciesCount: 2,
        highestValue: 4096,
      ),
      GoldManager.settleGame(
        gameId: 'concurrent-game',
        effectiveScore: 2000,
        newSpeciesCount: 2,
        highestValue: 4096,
      ),
    ]);
    expect(duplicateSettlements.reduce((a, b) => a + b), 14);
    expect(GoldManager.balance, 144);
    expect(GoldManager.cumulativeScore, 2000);

    await GoldManager.flushLocalChanges();
    await GoldManager.initializeLocal();
    expect(GoldManager.balance, 144);
    expect(GoldManager.settledGameIds, contains('concurrent-game'));
  });


}
