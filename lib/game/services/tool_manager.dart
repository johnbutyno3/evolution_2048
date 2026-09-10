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
  static const int _developerUnlimitedUses = 999999;

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
      final savedUses = _uses[type];
      final initialUses = SaveManager.developerUnlimitedTools
          ? _developerUnlimitedUses
          : (savedUses != null && savedUses > 0 ? savedUses : gameTool.maxUses);

      _tools.add(
        ToolState(
          tool: gameTool,
          uses: initialUses,
        ),
      );
    }
  }

  void _claimNextChapterRewardIfNeeded() {
    if (chapter == GameChapter.ocean || SaveManager.developerAllTools) return;

    final previousChapter = GameChapter.values[chapter.index - 1];
    final save = SaveManager.loadCached();
    if (save?['chapter'] != previousChapter.name ||
        save?['chapterComplete'] != true) {
      return;
    }

    final rewardKey = previousChapter.name;
    if (_rewardsClaimed.contains(rewardKey)) return;

    // Chapter tools are granted as one available use. Do not stack an extra use
    // on top of a saved/shop-purchased balance.
    for (final type in toolsForChapter(chapter)) {
      final current = _uses[type] ?? 0;
      if (current < 1) {
        _uses[type] = 1;
        final tool = getTool(type);
        if (tool != null) tool.usesRemaining = 1;
      }
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

  void refreshFromSavedProgress() {
    _uses.clear();

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

    for (final tool in _tools) {
      tool.usesRemaining = SaveManager.developerUnlimitedTools
          ? _developerUnlimitedUses
          : (_uses[tool.tool.type] ?? tool.tool.maxUses);
    }
  }

  bool use(GameToolType type) {
    final tool = getTool(type);
    if (tool == null || !tool.canUse) return false;

    if (SaveManager.developerUnlimitedTools) {
      tool.usesRemaining = _developerUnlimitedUses;
      return true;
    }

    if (!tool.use()) return false;
    _uses[type] = tool.usesRemaining;
    _persistProgress();
    return true;
  }

  static Future<void> addPurchasedUses(GameToolType type, int amount) async {
    if (amount <= 0) return;
    final save = SaveManager.loadCached() ?? <String, dynamic>{};
    final uses = <String, int>{};
    final rawUses = save[_saveKey];
    if (rawUses is Map) {
      for (final toolType in GameToolType.values) {
        final value = rawUses[toolType.name];
        uses[toolType.name] = value is num ? value.toInt().clamp(0, 1000000) : 0;
      }
    } else {
      for (final toolType in GameToolType.values) {
        uses[toolType.name] = 0;
      }
    }
    uses[type.name] = (uses[type.name] ?? 0) + amount;

    final rewards = <String>[];
    final rawRewards = save[_claimedKey];
    if (rawRewards is List) {
      rewards.addAll(rawRewards.whereType<String>());
    }

    await SaveManager.saveToolProgress(
      toolUses: uses,
      rewardsClaimed: rewards,
    );
  }

  void reset() {
    for (final tool in _tools) {
      tool.usesRemaining = SaveManager.developerUnlimitedTools
          ? _developerUnlimitedUses
          : (_uses[tool.tool.type] ?? tool.usesRemaining);
    }
  }

  void grantNextChapterReward() {
    for (final type in _nextChapterToolTypes) {
      _uses[type] = (_uses[type] ?? 0) + 1;
    }
    _persistProgress();
  }

  static List<GameToolType> toolsForChapter(GameChapter chapter) {
    if (SaveManager.developerAllTools) {
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

  void restoreFromSaveData(Map<String, dynamic> data) {
    final raw = data[_saveKey];
    if (raw is! Map) return;
    for (final type in GameToolType.values) {
      final value = raw[type.name];
      if (value is num) {
        _uses[type] = value.toInt().clamp(0, 1000000);
        final tool = getTool(type);
        if (tool != null) {
          tool.usesRemaining = SaveManager.developerUnlimitedTools
              ? _developerUnlimitedUses
              : _uses[type]!;
        }
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
