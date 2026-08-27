enum GameToolType {
  revive,
  timeRewind,
  historyRestore,
  duplicate,
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
  bool get isTimeRewind => type == GameToolType.timeRewind;
  bool get isHistoryRestore => type == GameToolType.historyRestore;
  bool get isDuplicate => type == GameToolType.duplicate;

  static const GameTool revive = GameTool(type: GameToolType.revive, name: 'Revive', description: 'Remove one tile from the board.', maxUses: 1);
  static const GameTool timeRewind = GameTool(type: GameToolType.timeRewind, name: 'Time Rewind', description: 'Undo the most recent valid move.', maxUses: 1);
  static const GameTool historyRestore = GameTool(type: GameToolType.historyRestore, name: 'History Restore', description: 'Restore one tile to its previous stage.', maxUses: 1);
  static const GameTool duplicate = GameTool(type: GameToolType.duplicate, name: 'Duplicate', description: 'Create a second tile with the same value.', maxUses: 1);
}

class ToolState {
  ToolState({required this.tool}) : usesRemaining = tool.maxUses;

  final GameTool tool;
  int usesRemaining;

  bool get canUse => usesRemaining > 0;

  bool use() {
    if (!canUse) return false;
    usesRemaining--;
    return true;
  }

  void reset() {
    usesRemaining = tool.maxUses;
  }
}
