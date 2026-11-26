import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'gold_manager.dart';

/// Offline tool inventory. Gold deduction and tool grant share one local wallet
/// record; every use is immediately persisted by GoldManager.
class ToolManager {
  ToolManager({required this.chapter}) {
    _initialize();
  }

  final GameChapter chapter;

  static String? _lastPurchaseError;
  static String? _lastPurchaseErrorCode;
  static const bool _allToolsEnabledForTest = false;

  static String? get lastPurchaseError => _lastPurchaseError;
  static String? get lastPurchaseErrorCode => _lastPurchaseErrorCode;
  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  static void clearCachedInventory() {
    _lastPurchaseError = null;
    _lastPurchaseErrorCode = null;
  }

  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _initialize() {
    _tools
      ..clear()
      ..addAll(
        toolsForChapter(chapter).map(
          (type) => ToolState(
            tool: _gameToolForType(type),
            uses: savedUsesFor(type),
          ),
        ),
      );
  }

  GameTool _gameToolForType(GameToolType type) => switch (type) {
    GameToolType.revive => GameTool.revive,
    GameToolType.timeRewind => GameTool.timeRewind,
    GameToolType.positionSwap => GameTool.positionSwap,
    GameToolType.duplicate => GameTool.duplicate,
  };

  ToolState? getTool(GameToolType type) {
    for (final tool in _tools) {
      if (tool.tool.type == type) return tool;
    }
    return null;
  }

  bool canUse(GameToolType type) =>
      getTool(type) != null && savedUsesFor(type) > 0;

  void refreshFromSavedProgress() {
    for (final tool in _tools) {
      tool.usesRemaining = savedUsesFor(tool.tool.type);
    }
  }

  static String toolCode(GameToolType type) => switch (type) {
    GameToolType.timeRewind => 'UNDO',
    GameToolType.revive => 'REMOVE',
    GameToolType.positionSwap => 'SWAP',
    GameToolType.duplicate => 'DUPLICATE',
  };

  static int packagePrice(GameToolType type, int amount) {
    const packages = <GameToolType, List<int>>{
      GameToolType.timeRewind: [50, 225, 700, 1500],
      GameToolType.revive: [100, 450, 1400, 3000],
      GameToolType.positionSwap: [200, 900, 2800, 6000],
      GameToolType.duplicate: [500, 2250, 7000, 15000],
    };
    final index = const [1, 5, 20, 50].indexOf(amount);
    if (index < 0) throw ArgumentError.value(amount, 'amount');
    return packages[type]![index];
  }

  static Future<bool> purchase(GameToolType type, int amount) async {
    _lastPurchaseError = null;
    _lastPurchaseErrorCode = null;
    if (!const [1, 5, 20, 50].contains(amount)) {
      _lastPurchaseErrorCode = 'INVALID_QUANTITY';
      _lastPurchaseError = 'Invalid tool package quantity.';
      return false;
    }

    final purchased = await GoldManager.purchaseTool(
      toolCode: toolCode(type),
      amount: amount,
      cost: packagePrice(type, amount),
      transactionId:
          'tool-purchase:${toolCode(type)}:${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!purchased) {
      _lastPurchaseErrorCode = 'INSUFFICIENT_GOLD';
      _lastPurchaseError = 'Not enough Gold or purchase could not be saved.';
      return false;
    }
    return true;
  }

  bool consumeLocal(GameToolType type) {
    final tool = getTool(type);
    if (tool == null) return false;
    if (!GoldManager.consumeToolLocal(toolCode(type))) return false;
    tool.usesRemaining = savedUsesFor(type);
    return true;
  }

  static int savedUsesFor(GameToolType type) =>
      GoldManager.toolUses(toolCode(type));

  static Map<GameToolType, int> savedInventory() => <GameToolType, int>{
    for (final type in GameToolType.values) type: savedUsesFor(type),
  };

  void reset() => refreshFromSavedProgress();

  /// Inventory is already local and durable; no network refresh is required.
  static Future<void> refreshInventory() async {}

  /// Kept for old gameplay call sites. Local tool consumption is already
  /// committed to the wallet and must not be replayed as another debit.
  static void clearSessionUsage() {}

  static void restoreSessionUsageFromReplayLog(dynamic replayLog) {}

  static List<GameToolType> toolsForChapter(GameChapter chapter) {
    if (_allToolsEnabledForTest) {
      return List<GameToolType>.from(GameToolType.values);
    }
    return switch (chapter) {
      GameChapter.ocean => [GameToolType.timeRewind],
      GameChapter.land => [
        GameToolType.timeRewind,
        GameToolType.revive,
      ],
      GameChapter.sky => [
        GameToolType.timeRewind,
        GameToolType.revive,
        GameToolType.positionSwap,
      ],
      GameChapter.history || GameChapter.tech => [
        GameToolType.timeRewind,
        GameToolType.revive,
        GameToolType.positionSwap,
        GameToolType.duplicate,
      ],
      GameChapter.universe => [GameToolType.timeRewind],
    };
  }
}
