enum GameToolType {
  revive,
  timeRewind,
}

class GameTool {
  const GameTool({
    required this.type,
    required this.name,
    required this.description,
    required this.maxUses,
  });

  final GameToolType type;
  final String name;
  final String description;
  final int maxUses;

  bool get isRevive => type == GameToolType.revive;

  bool get isTimeRewind =>
      type == GameToolType.timeRewind;

  static const GameTool revive = GameTool(
    type: GameToolType.revive,
    name: 'Revive',
    description:
        'Remove one creature from the board.',
    maxUses: 1,
  );

  static const GameTool timeRewind = GameTool(
    type: GameToolType.timeRewind,
    name: 'Time Rewind',
    description:
        'Undo the most recent valid move.',
    maxUses: 1,
  );
}

class ToolState {
  ToolState({
    required this.tool,
  }) : usesRemaining = tool.maxUses;

  final GameTool tool;

  int usesRemaining;

  bool get canUse => usesRemaining > 0;

  bool use() {
    if (!canUse) {
      return false;
    }

    usesRemaining--;
    return true;
  }

  void reset() {
    usesRemaining = tool.maxUses;
  }
}