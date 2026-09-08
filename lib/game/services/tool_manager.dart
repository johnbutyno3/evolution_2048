import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'save_manager.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _loadSavedUses();
    _initialize();
  }

  final GameChapter chapter;

  static const String _saveKey = 'toolUses';
  final Map<GameToolType, int> _uses = <GameToolType, int>{};
  final List<ToolState> _tools = <ToolState>[];

  List<ToolState> get tools => List.unmodifiable(_tools);

  bool get hasTools => _tools.isNotEmpty;

  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _loadSavedUses() {
    final save = SaveManager.loadCached();
    final raw = save?[_saveKey];
    if (raw is Map) {
      for (final type in GameToolType.values) {
        final value = raw[type.name];
        if (value is num) {
          _uses[type] = value.toInt().clamp(0, 1000000);
        }
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
    return true;
  }

  /// One successful chapter clear grants +1 use to every tool available
  /// in the next chapter. Unused uses are never reset and keep accumulating.
  void grantNextChapterReward() {
    for (final type in _nextChapterToolTypes) {
      _uses[type] = (_uses[type] ?? 1) + 1;
    }
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
    return switch (chapter) {
      GameChapter.ocean => toolsForChapter(GameChapter.land),
      GameChapter.land => toolsForChapter(GameChapter.sky),
      GameChapter.sky => toolsForChapter(GameChapter.history),
      GameChapter.history => toolsForChapter(GameChapter.tech),
      GameChapter.tech => toolsForChapter(GameChapter.universe),
      GameChapter.universe => const [],
    };
  }

  Map<String, int> createSaveData() {
    final result = <String, int>{};
    for (final type in GameToolType.values) {
      final tool = getTool(type);
      if (tool != null) {
        _uses[type] = tool.usesRemaining;
      }
      result[type.name] = _uses[type] ?? 1;
    }
    return result;
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
          tool.usesRemaining = _uses[type]!;
        }
      }
    }
  }
}
