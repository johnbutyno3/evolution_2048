import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';

class ToolManager {
  ToolManager({required this.chapter}) {
    _initialize();
  }

  final GameChapter chapter;
  final List<ToolState> _tools = [];

  List<ToolState> get tools => List.unmodifiable(_tools);
  bool get hasTools => _tools.isNotEmpty;
  int get availableToolCount => _tools.where((tool) => tool.canUse).length;

  void _initialize() {
    _tools.clear();

    switch (chapter) {
      case GameChapter.ocean:
        // Chapter 1 has no tools.
        break;
      case GameChapter.land:
        _tools.add(ToolState(tool: GameTool.revive));
        break;
      case GameChapter.sky:
        _tools.add(ToolState(tool: GameTool.revive));
        _tools.add(ToolState(tool: GameTool.timeRewind));
        break;
      case GameChapter.history:
        _tools.add(ToolState(tool: GameTool.revive));
        _tools.add(ToolState(tool: GameTool.timeRewind));
        _tools.add(ToolState(tool: GameTool.positionSwap));
        break;
      case GameChapter.tech:
        _tools.add(ToolState(tool: GameTool.revive));
        _tools.add(ToolState(tool: GameTool.timeRewind));
        _tools.add(ToolState(tool: GameTool.positionSwap));
        _tools.add(ToolState(tool: GameTool.duplicate));
        break;
      case GameChapter.universe:
        // Chapter 6 is the ultimate challenge: tools are disabled.
        break;
    }
  }

  ToolState? getTool(GameToolType type) {
    for (final tool in _tools) {
      if (tool.tool.type == type) return tool;
    }
    return null;
  }

  bool canUse(GameToolType type) => getTool(type)?.canUse ?? false;

  bool use(GameToolType type) => getTool(type)?.use() ?? false;

  void reset() {
    for (final tool in _tools) {
      tool.reset();
    }
  }
}
