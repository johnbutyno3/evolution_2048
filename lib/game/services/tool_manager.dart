import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'life_manager.dart';
import '../../services/player_progress_service.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _loadSavedProgress();
    _initialize();
    _claimNextChapterRewardIfNeeded();
  }

  final GameChapter chapter;

  static const int _unlimitedUses = 999999;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static final Map<GameToolType, int> _serverUses = {};
  static bool _allToolsEnabledForTest = false;

  static bool get allToolsEnabledForTest => _allToolsEnabledForTest;

  final Map<GameToolType, int> _uses = <GameToolType, int>{};
  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _loadSavedProgress() {}

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

  void _claimNextChapterRewardIfNeeded() {}

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
    _uses.clear();
    for (final tool in _tools) {
      tool.usesRemaining = savedUsesFor(tool.tool.type);
    }
  }

  /// Refreshes the authoritative tool inventory and applies it to the
  /// currently displayed tool states before gameplay actions are enabled.
  Future<void> refreshServerState() async {
    await refreshInventory();
    refreshFromSavedProgress();
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
      return true;
    } on FirebaseFunctionsException {
      return false;
    }
  }

  Future<bool> useServer(GameToolType type) async {
    if (LifeManager.isGoldenMember && type == GameToolType.timeRewind) {
      final tool = getTool(type);
      if (tool != null) tool.usesRemaining = _unlimitedUses;
      return true;
    }
    final sessionId = PlayerProgressService.instance.activeGameSessionId;
    if (sessionId == null || sessionId.isEmpty) return false;
    try {
      final result = await _functions.httpsCallable('useTool').call({
        'toolType': type.name,
        'sessionId': sessionId,
      });
      final uses = result.data is Map ? result.data['uses'] : null;
      if (uses is! num) return false;
      _serverUses[type] = uses.toInt();
      final tool = getTool(type);
      if (tool != null) tool.usesRemaining = uses.toInt();
      return true;
    } on FirebaseFunctionsException {
      return false;
    }
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

  void grantNextChapterReward() {
    for (final type in _nextChapterToolTypes) {
      _uses[type] = (_serverUses[type] ?? 0) + 1;
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

  List<GameToolType> get _nextChapterToolTypes {
    if (chapter == GameChapter.universe) return const [];
    return toolsForChapter(GameChapter.values[chapter.index + 1]);
  }

  Map<String, int> createSaveData() {
    for (final type in GameToolType.values) {
      final tool = getTool(type);
      if (tool != null) _uses[type] = tool.usesRemaining;
    }
    return <String, int>{
      for (final type in GameToolType.values) type.name: _uses[type] ?? 0,
    };
  }

}
