import 'creature.dart';

enum GameChapter { ocean, land, sky, history, tech, universe }

class GameTile {
  GameTile({required this.value, this.chapter = GameChapter.ocean});

  int value;
  final GameChapter chapter;

  Creature get creature {
    final creature = switch (chapter) {
      GameChapter.ocean => Creature.fromValue(value),
      GameChapter.land => Creature.fromChapter2Value(value),
      GameChapter.sky => Creature.fromChapter3Value(value),
      GameChapter.history => Creature.fromChapter4Value(value),
      GameChapter.tech => Creature.fromChapter5Value(value),
      GameChapter.universe => Creature.fromChapter6Value(value),
    };

    if (creature == null) {
      throw StateError(
        'Unsupported creature tile value: $value in chapter: $chapter',
      );
    }

    return creature;
  }

  bool get isFinal {
    return switch (chapter) {
      GameChapter.ocean => value == 4096,
      GameChapter.land => value == 8192,
      GameChapter.sky => value == 16384,
      GameChapter.history => value == 32768,
      GameChapter.tech => value == 65536,
      GameChapter.universe => value == 131072,
    };
  }

  bool get is2048 => value == 2048;

  bool get is4096 => value == 4096;

  bool get is8192 => value == 8192;

  void merge() {
    if (isFinal) {
      throw StateError(
        'Cannot merge final evolution stage: $value in chapter: $chapter',
      );
    }

    value *= 2;
  }
}
