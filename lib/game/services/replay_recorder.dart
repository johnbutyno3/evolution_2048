import '../models/game_board.dart';
import '../models/replay_event.dart';
import 'replay_log.dart';
import 'save_manager.dart';

/// Records the player's local gameplay actions into the untrusted replay log.
///
/// This class deliberately observes the board before/after an action instead
/// of generating randomness itself. The server remains responsible for
/// validating every event and replaying the complete attempt.
class ReplayRecorder {
  ReplayRecorder({required this.chapter});

  final String chapter;
  ReplayLog? _log;

  ReplayLog? get log => _log?.copy();

  bool get isStarted => _log != null;

  void start(GameBoard board) {
    _log = ReplayLog(
      chapter: chapter,
      initialTiles: _tiles(board),
    );
    _save();
  }

  void restoreFromSave(Map<String, dynamic>? data, GameBoard board) {
    final restored = ReplayLog.tryFromJson(data?['replayLog']);

    if (restored != null && restored.chapter == chapter) {
      _log = restored;
      return;
    }

    start(board);
  }

  /// Records a normal 2048 move. The newly spawned tile is detected from the
  /// board difference after the engine has completed the move.
  void recordMove({
    required String direction,
    required GameBoard before,
    required GameBoard after,
  }) {
    final log = _log;
    if (log == null) return;

    final spawn = _findSpawn(before, after);

    log.events.add(
      ReplayEvent.move(
        direction: direction,
        spawnIndex: spawn.$1,
        spawnValue: spawn.$2,
      ),
    );

    _save();
  }

  void recordRevive({required int row, required int column}) {
    final log = _log;
    if (log == null) return;

    log.events.add(
      ReplayEvent.revive(index: row * GameBoard.size + column),
    );
    _save();
  }

  void recordPositionSwap({
    required int firstRow,
    required int firstColumn,
    required int secondRow,
    required int secondColumn,
  }) {
    final log = _log;
    if (log == null) return;

    log.events.add(
      ReplayEvent.positionSwap(
        firstIndex: firstRow * GameBoard.size + firstColumn,
        secondIndex: secondRow * GameBoard.size + secondColumn,
      ),
    );
    _save();
  }

  void recordDuplicate({
    required int sourceRow,
    required int sourceColumn,
    required int targetRow,
    required int targetColumn,
  }) {
    final log = _log;
    if (log == null) return;

    log.events.add(
      ReplayEvent.duplicate(
        sourceIndex: sourceRow * GameBoard.size + sourceColumn,
        targetIndex: targetRow * GameBoard.size + targetColumn,
      ),
    );
    _save();
  }

  void recordTimeRewind() {
    final log = _log;
    if (log == null) return;

    log.events.add(ReplayEvent.timeRewind());
    _save();
  }

  void _save() {
    final current = _log;
    if (current == null) return;

    final save = SaveManager.loadCached(chapter: chapter) ??
        <String, dynamic>{'chapter': chapter};

    save['replayLog'] = current.toJson();
    SaveManager.save(save);
  }

  List<int?> _tiles(GameBoard board) {
    return board.tiles.map((tile) => tile?.value).toList();
  }

  (int, int) _findSpawn(GameBoard before, GameBoard after) {
    final beforeTiles = _tiles(before);
    final afterTiles = _tiles(after);

    for (var index = 0; index < afterTiles.length; index++) {
      if (beforeTiles[index] == null && afterTiles[index] != null) {
        return (index, afterTiles[index]!);
      }
    }

    // A successful move that completes the chapter can legitimately have no
    // spawn because the engine stops before spawning another tile. The server
    // interprets -1/-1 as "no spawn" and validates that condition itself.
    return (-1, -1);
  }
}
