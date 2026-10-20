import 'dart:async';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'life_manager.dart';
import 'gold_manager.dart';
import 'pending_operation_store.dart';

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
  static final Map<GameToolType, int> _sessionUses = {};
  static int _inventoryGeneration = 0;
  static bool _allToolsEnabledForTest = false;
  static String? _lastPurchaseError;

  static String _purchaseKey(GameToolType type, int amount) =>
      '${type.name}:$amount';

  static String? get lastPurchaseError => _lastPurchaseError;

  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  /// Clears account-scoped cached inventory when the authenticated user changes.
  /// Inventory must never leak from a previous Firebase account.
  static void clearCachedInventory() {
    _inventoryGeneration++;
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
  static Future<void> refreshInventory() {
    return _refreshInventoryFromServer();
  }

  static Future<void> _refreshInventoryFromServer() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final generation = _inventoryGeneration;
    try {
      final result = await _functions.httpsCallable('getToolInventory').call();
      if (_inventoryGeneration != generation ||
          FirebaseAuth.instance.currentUser?.uid != uid) return;
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      _allToolsEnabledForTest = data['allToolsEnabledForTest'] == true;
      final inventory = data['inventory'];
      if (inventory is! Map) return;

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

  /// Clears the optimistic usage overlay when a brand-new game session is created.
  static void clearSessionUsage() {
    _sessionUses.clear();
  }

  /// Rebuilds the usage overlay from the persisted replay log of the active session.
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    final generation = _inventoryGeneration;
    _lastPurchaseError = null;
    final key = _purchaseKey(type, amount);
    try {
      return await PendingOperationStore.runExclusive(
        'tool_purchase',
        key,
        () async {
          if (_inventoryGeneration != generation ||
              FirebaseAuth.instance.currentUser?.uid != uid) return false;
          await GoldManager.refresh();
          if (_inventoryGeneration != generation ||
              FirebaseAuth.instance.currentUser?.uid != uid) return false;
          try {
            final operationId = await PendingOperationStore.getOrCreate('tool_purchase', key);
            final result = await _functions.httpsCallable('purchaseTool').call({
              'toolType': type.name,
              'amount': amount,
              'operationId': operationId,
            });
            if (_inventoryGeneration != generation ||
                FirebaseAuth.instance.currentUser?.uid != uid) return false;
            final data = result.data is Map
                ? Map<String, dynamic>.from(result.data as Map)
                : <String, dynamic>{};
            final uses = data['uses'];
            final balance = data['balance'];
            if (uses is! num || balance is! num) {
              _lastPurchaseError = 'Server returned an invalid purchase result.';
              return false;
            }
            _serverUses[type] = uses.toInt();
            GoldManager.applyServerState(data);
            await PendingOperationStore.complete('tool_purchase', key, expectedUid: uid);
            await refreshInventory();
            return _inventoryGeneration == generation &&
                FirebaseAuth.instance.currentUser?.uid == uid;
          } on FirebaseFunctionsException catch (error) {
            // Preserve the ID after ambiguous failures to prevent duplicate charges.
            await GoldManager.refresh();
            _lastPurchaseError = switch (error.code) {
              'failed-precondition' => error.message ?? 'Purchase precondition failed.',
              'permission-denied' => error.message ?? 'Account operation is restricted.',
              'unauthenticated' => 'Please sign in again.',
              'invalid-argument' => error.message ?? 'Invalid purchase request.',
              _ => error.message ?? 'Tool purchase failed (${error.code}).',
            };
            return false;
          }
        },
      );
    } on StateError {
      _lastPurchaseError = 'Please sign in again.';
      return false;
    }
  }

  /// Consumes a tool locally; server validates the replay log at settlement.
  bool consumeLocal(GameToolType type) {
    final tool = getTool(type);
    if (tool == null) return false;

    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      tool.usesRemaining = _unlimitedUses;
      return true;
    }

    if (!tool.canUse) return false;

    tool.usesRemaining -= 1;
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
