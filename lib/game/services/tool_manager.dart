import 'dart:async';

import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'life_manager.dart';
import 'gold_manager.dart';
import '../../services/supabase_account_service.dart';
import '../../services/supabase_tool_purchase_service.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _initialize();
  }

  final GameChapter chapter;

  static const int _unlimitedUses = 999999;
  static final Map<GameToolType, int> _serverUses = {};
  // Usage that belongs to the currently active local game session but has
  // not yet been settled against the account inventory on the server.
  // This must survive BACK/re-entry and must not be overwritten by a plain
  // account-inventory refresh.
  static final Map<GameToolType, int> _sessionUses = {};
  static bool _allToolsEnabledForTest = false;
  static String? _lastPurchaseError;

  static String? get lastPurchaseError => _lastPurchaseError;

  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  /// Clears account-scoped cached inventory when the authenticated user changes.
  /// Inventory must never leak from a previous signed-in account.
  static void clearCachedInventory() {
    _serverUses.clear();
    _sessionUses.clear();
    _allToolsEnabledForTest = false;
    _lastPurchaseError = null;
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

  /// Replaces the account inventory using a previously validated Supabase
  /// account snapshot. Tool codes are mapped explicitly to game tool types.
  static void applySupabaseInventory(Map<String, int> inventory) {
    final mapping = <String, GameToolType>{
      'UNDO': GameToolType.timeRewind,
      'REMOVE': GameToolType.revive,
      'SWAP': GameToolType.positionSwap,
      'DUPLICATE': GameToolType.duplicate,
    };
    final snapshot = <GameToolType, int>{};
    for (final item in mapping.entries) {
      final count = inventory[item.key];
      if (count == null || count < 0) {
        throw ArgumentError('Invalid Supabase tool inventory: ${item.key}');
      }
      snapshot[item.value] = count;
    }
    _serverUses
      ..clear()
      ..addAll(snapshot);
    _sessionUses.clear();
    _allToolsEnabledForTest = false;
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
      final snapshot = await SupabaseAccountService.fetchSnapshot();
      const mapping = <String, GameToolType>{
        'UNDO': GameToolType.timeRewind,
        'REMOVE': GameToolType.revive,
        'SWAP': GameToolType.positionSwap,
        'DUPLICATE': GameToolType.duplicate,
      };
      final refreshed = <GameToolType, int>{
        for (final entry in mapping.entries) entry.value: snapshot.tools[entry.key]!,
      };
      // Refresh the account inventory without clearing the active game's
      // pending local tool-use overlay.
      _serverUses
        ..clear()
        ..addAll(refreshed);
    } on SupabaseAccountException {
      // Keep the last validated account snapshot. A failed read must never
      // synthesize inventory or grant additional tool uses.
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
    _lastPurchaseError = null;
    if (!const [1, 5, 20, 50].contains(amount)) {
      _lastPurchaseError = 'Invalid tool package quantity.';
      return false;
    }

    final toolCode = switch (type) {
      GameToolType.timeRewind => 'UNDO',
      GameToolType.revive => 'REMOVE',
      GameToolType.positionSwap => 'SWAP',
      GameToolType.duplicate => 'DUPLICATE',
    };

    try {
      final data = await SupabaseToolPurchaseService.purchase(
        toolCode: toolCode,
        quantity: amount,
      );
      final uses = data['uses'] as num;
      final balance = data['balance'] as num;

      // The trusted Supabase RPC commits Gold deduction and tool grant in one
      // database transaction. Apply both values only after validating response.
      _serverUses[type] = uses.toInt();
      GoldManager.applySupabaseBalance(balance.toInt());
      return true;
    } on SupabaseToolPurchaseException catch (error) {
      _lastPurchaseError = error.message;
      return false;
    }
  }

  /// Consumes a tool locally.
  ///
  /// Gameplay never waits for the server for an individual tool use. The local
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
    // restarted/completed. Track this use separately so an account inventory
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