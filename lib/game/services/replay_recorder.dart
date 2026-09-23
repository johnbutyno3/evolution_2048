import '../models/game_board.dart';
import '../models/replay_event.dart';
import 'replay_log.dart';
import 'save_manager.dart';

/// Records the player's local gameplay actions into the untrusted replay log.
///
/// This class deliberately records the explicit random spawn supplied by the
/// game engine. The server remains responsible for validating every event and
/// replaying the complete attempt.
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

  /// Records a normal 2048 move together with the exact tile spawned by the
  /// engine after the move. The server will validate that spawn during replay.
  void recordMove({
    required String direction,
    required int spawnIndex,
    required int spawnValue,
  }) {
    final log = _log;
    if (log == null) return;

    log.events.add(
      ReplayEvent.move(
        direction: direction,
        spawnIndex: spawnIndex,
        spawnValue: spawnValue,
      ),
    );

    _save();
  }

  void recordRevive({
    required int row,
    required int column,
    int? spawnIndex,
    int? spawnValue,
  }) {
    final log = _log;
    if (log == null) return;

    log.events.add(
      ReplayEvent.revive(
        index: row * 4 + column,
        spawnIndex: spawnIndex,
        spawnValue: spawnValue,
      ),
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
        firstIndex: firstRow * 4 + firstColumn,
        secondIndex: secondRow * 4 + secondColumn,
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
        sourceIndex: sourceRow * 4 + sourceColumn,
        targetIndex: targetRow * 4 + targetColumn,
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

  void removeLastEvent() {
    final log = _log;
    if (log == null || log.events.isEmpty) return;
    log.events.removeLast();
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
}
