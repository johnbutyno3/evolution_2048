import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'life_manager.dart';
import 'gold_manager.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _initialize();
  }

  final GameChapter chapter;

  static const int _unlimitedUses = 999999;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static final Map<GameToolType, int> _serverUses = {};
  static bool _allToolsEnabledForTest = false;

  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _initialize() {
    _tools.clear();

    for (final type in toolsForChapter(chapter)) {
      final gameTool = _gameToolForType(type);
      final savedUses = _serverUses[type] ?? 0;
      final initialUses = savedUses > 0
          ? savedUses
          : (chapter == GameChapter.ocean ? gameTool.maxUses : 0);

      _tools.add(ToolState(tool: gameTool, uses: initialUses));
    }
  }

  GameTool _gameToolForType(GameToolType type) {
    return switch (type) {
      GameToolType.revive => GameTool.revive,
      GameToolType.timeRewind => GameTool.timeRewind,
      GameToolType.positionSwap => GameTool.positionSwap,
      GameToolType.duplicate => GameTool.duplicate,
    };
  }

  ToolState? getTool(GameToolType type) {
    for (final tool in _tools) {
      if (tool.tool.type == type) return tool;
    }
    return null;
  }

  bool canUse(GameToolType type) => getTool(type)?.canUse ?? false;

  void refreshFromSavedProgress() {
    for (final tool in _tools) {
      tool.usesRemaining = savedUsesFor(tool.tool.type);
    }
  }

  static Future<void> refreshInventory() async {
    try {
      final result = await _functions.httpsCallable('getToolInventory').call();
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      _allToolsEnabledForTest = data['allToolsEnabledForTest'] == true;
      final inventory = data['inventory'];
      if (inventory is! Map) return;
      for (final entry in inventory.entries) {
        final type = GameToolType.values.where(
          (value) => value.name == entry.key,
        );
        if (type.isNotEmpty && entry.value is num) {
          _serverUses[type.first] = (entry.value as num).toInt();
        }
      }
    } on FirebaseFunctionsException {
      return;
    }
  }

  static Future<bool> purchase(GameToolType type, int amount) async {
    try {
      final result = await _functions.httpsCallable('purchaseTool').call({
        'toolType': type.name,
        'amount': amount,
      });
      final uses = result.data is Map ? result.data['uses'] : null;
      if (uses is! num) return false;
      _serverUses[type] = uses.toInt();
      if (result.data is Map) {
        GoldManager.applyServerState(Map<String, dynamic>.from(result.data as Map));
      }
      return true;
    } on FirebaseFunctionsException {
      return false;
    }
  }

  /// Consumes a tool locally.
  ///
  /// Gameplay never waits for Firebase for an individual tool use. The local
  /// replay log is the authoritative input for the eventual server validation
  /// when the game session ends.
  bool consumeLocal(GameToolType type) {
    final tool = getTool(type);
    if (tool == null || !tool.canUse) return false;

    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      tool.usesRemaining = _unlimitedUses;
      return true;
    }

    tool.usesRemaining -= 1;
    return true;
  }

  /// Returns the globally saved inventory for a tool.
  ///
  /// Tool inventory is cumulative across chapters, so this can be used by
  /// profile/shop UI even when the tool is not currently unlocked.
  static int savedUsesFor(GameToolType type) {
    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      return _unlimitedUses;
    }
    return _serverUses[type] ?? 0;
  }

  static Map<GameToolType, int> savedInventory() {
    return <GameToolType, int>{
      for (final type in GameToolType.values) type: savedUsesFor(type),
    };
  }

  void reset() {
    for (final tool in _tools) {
      tool.usesRemaining = savedUsesFor(tool.tool.type);
    }
  }

  static List<GameToolType> toolsForChapter(GameChapter chapter) {
    if (_allToolsEnabledForTest) return List<GameToolType>.from(GameToolType.values);
    return switch (chapter) {
      GameChapter.ocean => [GameToolType.timeRewind],
      GameChapter.land => [GameToolType.timeRewind, GameToolType.revive],
      GameChapter.sky => [
        GameToolType.timeRewind,
        GameToolType.revive,
        GameToolType.positionSwap,
      ],
      GameChapter.history => [
        GameToolType.timeRewind,
        GameToolType.revive,
        GameToolType.positionSwap,
        GameToolType.duplicate,
      ],
      GameChapter.tech => [
        GameToolType.timeRewind,
        GameToolType.revive,
        GameToolType.positionSwap,
        GameToolType.duplicate,
      ],
      GameChapter.universe => [GameToolType.timeRewind],
    };
  }

}
