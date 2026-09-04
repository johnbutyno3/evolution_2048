import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';

class ToolManager {
  ToolManager({required this.chapter, this.unlimitedTools = true}) {
    _initialize();
  }

  final GameChapter chapter;

  /// Debug/testing cheat: when enabled, tools do not consume their uses.
  final bool unlimitedTools;

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
    _tools.add(ToolState(tool: tool, unlimited: unlimitedTools));
  }

  ToolState? getTool(GameToolType type) {
    for (final tool in _tools) {
      if (tool.tool.type == type) {
        return tool;
      }
    }
    return null;
  }

  bool canUse(GameToolType type) {
    return getTool(type)?.canUse ?? false;
  }

  bool use(GameToolType type) {
    return getTool(type)?.use() ?? false;
  }

  void reset() {
    for (final tool in _tools) {
      tool.reset();
    }
  }
}
