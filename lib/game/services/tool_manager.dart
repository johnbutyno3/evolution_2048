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
  // Usage that belongs to the currently active local game session but has
  // not yet been settled against the account inventory on the server.
  // This must survive BACK/re-entry and must not be overwritten by a plain
  // account-inventory refresh.
  static final Map<GameToolType, int> _sessionUses = {};
  static bool _allToolsEnabledForTest = false;

  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  /// Clears account-scoped cached inventory when the authenticated user changes.
  /// Inventory must never leak from a previous Firebase account.
  static void clearCachedInventory() {
    _serverUses.clear();
    _sessionUses.clear();
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

  bool canUse(GameToolType type) {
    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      return true;
    }
    return getTool(type)?.canUse ?? false;
  }

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

      // Firebase is authoritative for inventory. Replace the account-scoped
      // snapshot instead of merging into the previous in-memory values.
      // Otherwise a previous session can leave a stale use count visible
      // until the next purchase/consumption.
      final serverSnapshot = <GameToolType, int>{};
      for (final type in GameToolType.values) {
        final raw = inventory[type.name];
        serverSnapshot[type] = raw is num && raw.toInt() >= 0 ? raw.toInt() : 0;
      }
      _serverUses
        ..clear()
        ..addAll(serverSnapshot);
    } on FirebaseFunctionsException {
      return;
    }
  }

  /// Clears the optimistic usage overlay when a brand-new game session is
  /// created. The previous session will have been settled by the server.
  static void clearSessionUsage() {
    _sessionUses.clear();
  }

  /// Rebuilds the usage overlay from the persisted replay log of the active
  /// local session. The account inventory itself remains server-authoritative;
  /// the overlay represents uses that are still pending session settlement.
  static void restoreSessionUsageFromReplayLog(dynamic replayLog) {
    _sessionUses.clear();
    if (replayLog is! Map) return;
    final events = replayLog['events'];
    if (events is! List) return;

    for (final rawEvent in events) {
      if (rawEvent is! Map) continue;
      final rawType = rawEvent['type'];
      if (rawType is! String) continue;

      final type = switch (rawType) {
        'revive' => GameToolType.revive,
        'timeRewind' => GameToolType.timeRewind,
        'positionSwap' => GameToolType.positionSwap,
        'duplicate' => GameToolType.duplicate,
        _ => null,
      };
      if (type == null) continue;
      _sessionUses[type] = (_sessionUses[type] ?? 0) + 1;
    }
  }

  static Future<bool> purchase(GameToolType type, int amount) async {
    // Refresh the wallet immediately before purchase so an admin grant or a
    // recent Gold transaction is not hidden behind an old client cache.
    await GoldManager.refresh();

    try {
      final result = await _functions.httpsCallable('purchaseTool').call({
        'toolType': type.name,
        'amount': amount,
      });
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      final uses = data['uses'];
      final balance = data['balance'];

      // The purchase callable is atomic: Gold deduction and tool inventory
      // grant are committed together. Accept the result only when both
      // authoritative values are present, then refresh the complete inventory
      // so every tool state reflects the same server snapshot.
      if (uses is! num || balance is! num) return false;
      _serverUses[type] = uses.toInt();
      GoldManager.applyServerState(data);
      await refreshInventory();
      return true;
    } on FirebaseFunctionsException catch (error) {
      // Re-read the authoritative wallet after a rejected purchase so a
      // stale client cache cannot continue displaying an incorrect balance.
      await GoldManager.refresh();
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
    // The account inventory is not settled until the active session is
    // restarted/completed. Track this use separately so a Firebase inventory
    // refresh cannot resurrect the tool during BACK/re-entry.
    _sessionUses[type] = (_sessionUses[type] ?? 0) + 1;
    return true;
  }

  static int savedUsesFor(GameToolType type) {
    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      return _unlimitedUses;
    }
    final accountUses = _serverUses[type] ?? 0;
    final pendingSessionUses = _sessionUses[type] ?? 0;
    final remaining = accountUses - pendingSessionUses;
    return remaining < 0 ? 0 : remaining;
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