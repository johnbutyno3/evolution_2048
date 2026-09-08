import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'save_manager.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _loadSavedProgress();
    _initialize();
    _claimNextChapterRewardIfNeeded();
  }

  final GameChapter chapter;

  static const String _saveKey = 'toolUses';
  static const String _claimedKey = 'toolRewardsClaimed';

  final Map<GameToolType, int> _uses = <GameToolType, int>{};
  final Set<String> _rewardsClaimed = <String>{};
  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _loadSavedProgress() {
    final save = SaveManager.loadCached();
    final rawUses = save?[_saveKey];
    if (rawUses is Map) {
      for (final type in GameToolType.values) {
        final value = rawUses[type.name];
        if (value is num) {
          _uses[type] = value.toInt().clamp(0, 1000000);
        }
      }
    }

    final rawClaimed = save?[_claimedKey];
    if (rawClaimed is List) {
      for (final value in rawClaimed) {
        if (value is String) _rewardsClaimed.add(value);
      }
    }
  }

  void _initialize() {
    _tools.clear();
    for (final type in toolsForChapter(chapter)) {
      final gameTool = _gameToolForType(type);
      _tools.add(
        ToolState(
          tool: gameTool,
          uses: _uses[type] ?? gameTool.maxUses,
        ),
      );
    }
  }

  void _claimNextChapterRewardIfNeeded() {
    if (chapter == GameChapter.ocean) return;

    final previousChapter = GameChapter.values[chapter.index - 1];
    final save = SaveManager.loadCached();
    if (save?['chapter'] != previousChapter.name ||
        save?['chapterComplete'] != true) {
      return;
    }

    final rewardKey = previousChapter.name;
    if (_rewardsClaimed.contains(rewardKey)) return;

    for (final type in toolsForChapter(chapter)) {
      _uses[type] = (_uses[type] ?? 1) + 1;
      final tool = getTool(type);
      if (tool != null) tool.usesRemaining = _uses[type]!;
    }

    _rewardsClaimed.add(rewardKey);
    _persistProgress();
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

  bool use(GameToolType type) {
    final tool = getTool(type);
    if (tool == null || !tool.use()) return false;
    _uses[type] = tool.usesRemaining;
    _persistProgress();
    return true;
  }

  /// Retained for callers/tests. The actual reward is claimed automatically
  /// when the next chapter is opened after a real chapter completion.
  void grantNextChapterReward() {
    for (final type in _nextChapterToolTypes) {
      _uses[type] = (_uses[type] ?? 1) + 1;
    }
    _persistProgress();
  }

  static List<GameToolType> toolsForChapter(GameChapter chapter) {
    return switch (chapter) {
      GameChapter.ocean => [GameToolType.timeRewind],
      GameChapter.land => [
          GameToolType.timeRewind,
          GameToolType.positionSwap,
        ],
      GameChapter.sky => [
          GameToolType.timeRewind,
          GameToolType.positionSwap,
          GameToolType.revive,
        ],
      GameChapter.history => [
          GameToolType.timeRewind,
          GameToolType.positionSwap,
          GameToolType.revive,
          GameToolType.duplicate,
        ],
      GameChapter.tech => [
          GameToolType.timeRewind,
          GameToolType.positionSwap,
          GameToolType.revive,
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
      for (final type in GameToolType.values) type.name: _uses[type] ?? 1,
    };
  }

  void restoreFromSaveData(Map<String, dynamic> data) {
    final raw = data[_saveKey];
    if (raw is! Map) return;
    for (final type in GameToolType.values) {
      final value = raw[type.name];
      if (value is num) {
        _uses[type] = value.toInt().clamp(0, 1000000);
        final tool = getTool(type);
        if (tool != null) tool.usesRemaining = _uses[type]!;
      }
    }
  }

  void _persistProgress() {
    SaveManager.saveToolProgress(
      toolUses: createSaveData(),
      rewardsClaimed: _rewardsClaimed.toList(),
    );
  }
}
