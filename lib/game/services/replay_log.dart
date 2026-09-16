import '../models/replay_event.dart';

/// Local, untrusted record of a game attempt.
///
/// This is intentionally kept compact and is never treated as authoritative.
/// The server will validate and replay it before accepting chapter completion.
class ReplayLog {
  static const int currentVersion = 1;

  ReplayLog({
    required this.chapter,
    required List<int?> initialTiles,
    List<ReplayEvent>? events,
  })  : initialTiles = List<int?>.from(initialTiles),
        events = List<ReplayEvent>.from(events ?? const <ReplayEvent>[]);

  final String chapter;
  final List<int?> initialTiles;
  final List<ReplayEvent> events;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': currentVersion,
        'replayVersion': currentVersion,
        'chapter': chapter,
        'initialTiles': initialTiles,
        'events': events.map((event) => event.toJson()).toList(),
      };

  static ReplayLog? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;

    final version = raw['version'] ?? raw['replayVersion'];
    if (version != currentVersion) return null;

    final chapter = raw['chapter'];
    final initialTiles = raw['initialTiles'];
    final rawEvents = raw['events'];

    if (chapter is! String ||
        chapter.isEmpty ||
        initialTiles is! List ||
        initialTiles.length != 16 ||
        rawEvents is! List) {
      return null;
    }

    final tiles = <int?>[];
    for (final value in initialTiles) {
      if (value == null) {
        tiles.add(null);
      } else if (value is num && value.toInt() >= 2) {
        tiles.add(value.toInt());
      } else {
        return null;
      }
    }

    final events = <ReplayEvent>[];
    try {
      for (final rawEvent in rawEvents) {
        events.add(ReplayEvent.fromJson(rawEvent));
      }
    } on FormatException {
      return null;
    }

    return ReplayLog(
      chapter: chapter,
      initialTiles: tiles,
      events: events,
    );
  }

  ReplayLog copy() => ReplayLog(
        chapter: chapter,
        initialTiles: initialTiles,
        events: events,
      );
}
