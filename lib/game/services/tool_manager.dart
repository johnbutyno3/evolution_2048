import 'dart:async';

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

  /// Clears account-scoped cached inventory when the authenticated user changes.
  /// Inventory must never leak from a previous Firebase account.
  static void clearCachedInventory() {
    _serverUses.clear();
    _allToolsEnabledForTest = false;
  }

  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _initialize() {
    _tools.clear();

    for (final type in toolsForChapter(chapter)) {
      final gameTool = _gameToolForType(type);
      // Inventory is server-authoritative. Never synthesize a tool use
      // from GameTool.maxUses here: a missing/failed inventory read must not
      // silently grant a use. New accounts receive the initial C1 UNDO from
      // the server inventory initializer, which is synchronized before any
      // flow that requires authoritative tool state.
      final initialUses = _serverUses[type] ?? 0;

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

  /// Refreshes the server inventory.
  ///
  /// Callers that are allowed to wait for inventory synchronization may await
  /// this future. Game entry itself can still use [unawaited] so network
  /// latency never blocks the local-first game flow.
  static Future<void> refreshInventory() {
    return _refreshInventoryFromServer();
  }

  static Future<void> _refreshInventoryFromServer() async {
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
    if (tool == null) return false;

    // GOLDEN UNDO is unlimited even when the authoritative inventory has
    // never contained a purchased UNDO. Check membership before the normal
    // inventory gate so a stale/empty local inventory cannot block it.
    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      tool.usesRemaining = _unlimitedUses;
      return true;
    }

    if (!tool.canUse) return false;

    tool.usesRemaining -= 1;
    return true;
  }

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