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
        // Chapter 2 has exactly one tool.
        _tools.add(ToolState(tool: GameTool.revive));
        break;

      case GameChapter.sky:
        // Chapter 3 has exactly two tools.
        _tools.add(ToolState(tool: GameTool.revive));
        _tools.add(ToolState(tool: GameTool.timeRewind));
        break;

      case GameChapter.history:
        // Chapter 4 has no tools.
        break;
    }
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
    final tool = getTool(type);

    return tool?.canUse ?? false;
  }

  bool use(GameToolType type) {
    final tool = getTool(type);

    if (tool == null) {
      return false;
    }

    return tool.use();
  }

  void reset() {
    for (final tool in _tools) {
      tool.reset();
    }
  }
}
