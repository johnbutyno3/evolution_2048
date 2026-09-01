enum GameToolType { revive, timeRewind, positionSwap, duplicate }

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

  bool get isTimeRewind => type == GameToolType.timeRewind;

  bool get isPositionSwap => type == GameToolType.positionSwap;

  bool get isDuplicate => type == GameToolType.duplicate;

  static const GameTool revive = GameTool(
    type: GameToolType.revive,
    name: 'REMOVE',
    description: 'Remove one tile from the board.',
    maxUses: 1,
  );

  static const GameTool timeRewind = GameTool(
    type: GameToolType.timeRewind,
    name: 'UNDO',
    description: 'Undo the most recent valid move.',
    maxUses: 1,
  );

  static const GameTool positionSwap = GameTool(
    type: GameToolType.positionSwap,
    name: 'SWAP',
    description: 'Swap the positions of two tiles.',
    maxUses: 1,
  );

  static const GameTool duplicate = GameTool(
    type: GameToolType.duplicate,
    name: 'DUPLICATE',
    description: 'Copy a tile up to value 256 to an empty position.',
    maxUses: 1,
  );
}

class ToolState {
  ToolState({required this.tool, this.unlimited = false})
    : usesRemaining = tool.maxUses;

  final GameTool tool;

  final bool unlimited;

  int usesRemaining;

  bool get canUse {
    return unlimited || usesRemaining > 0;
  }

  String get usesLabel {
    return unlimited ? '∞' : '$usesRemaining';
  }

  bool use() {
    if (!canUse) {
      return false;
    }

    if (!unlimited) {
      usesRemaining--;
    }

    return true;
  }

  void reset() {
    usesRemaining = tool.maxUses;
  }
}
