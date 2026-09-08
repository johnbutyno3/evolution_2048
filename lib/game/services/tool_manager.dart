import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import 'save_manager.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _initialize();
  }

  final GameChapter chapter;

  static const String _saveKey = 'toolUses';

  final List<ToolState> _tools = [];

  List<ToolState> get tools => List.unmodifiable(_tools);

  bool get hasTools => _tools.isNotEmpty;

  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _initialize() {
    _tools.clear();

    switch (chapter) {
      case GameChapter.ocean:
        _add(GameTool.timeRewind);
        break;
      case GameChapter.land:
        _add(GameTool.timeRewind);
        _add(GameTool.positionSwap);
        break;
      case GameChapter.sky:
        _add(GameTool.timeRewind);
        _add(GameTool.positionSwap);
        _add(GameTool.revive);
        break;
      case GameChapter.history:
        _add(GameTool.timeRewind);
        _add(GameTool.positionSwap);
        _add(GameTool.revive);
        _add(GameTool.duplicate);
        break;
      case GameChapter.tech:
        _add(GameTool.timeRewind);
        _add(GameTool.positionSwap);
        _add(GameTool.revive);
        _add(GameTool.duplicate);
        break;
      case GameChapter.universe:
        _add(GameTool.timeRewind);
        break;
    }
  }

  void _add(GameTool tool) {
    final savedUses = _savedUses(tool.type);
    _tools.add(ToolState(tool: tool, uses: savedUses ?? tool.maxUses));
  }

  int? _savedUses(GameToolType type) {
    final save = SaveManager.loadCached();
    final raw = save?[_saveKey];
    if (raw is! Map) return null;
    final value = raw[type.name];
    return value is num ? value.toInt().clamp(0, 1000000) : null;
  }

  ToolState? getTool(GameToolType type) {
    for (final tool in _tools) {
      if (tool.tool.type == type) {
        return tool;
      }
    }
    return null;
  }

  bool canUse(GameToolType type) => getTool(type)?.canUse ?? false;

  bool use(GameToolType type) => getTool(type)?.use() ?? false;

  void addUsesForNextChapter() {
    for (final type in _nextChapterToolTypes) {
      final tool = getTool(type);
      if (tool != null) {
        tool.addUses(1);
      }
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
        result[type.name] = tool.usesRemaining;
      } else {
        final saved = _savedUses(type);
        if (saved != null) {
          result[type.name] = saved;
        }
      }
    }
    return result;
  }

  void restoreFromSaveData(Map<String, dynamic> data) {
    final raw = data[_saveKey];
    if (raw is! Map) return;

    for (final type in GameToolType.values) {
      final value = raw[type.name];
      if (value is num) {
        final tool = getTool(type);
        if (tool != null) {
          tool.usesRemaining = value.toInt().clamp(0, 1000000);
        }
      }
    }
  }
}
