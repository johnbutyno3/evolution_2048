import 'creature.dart';

enum GameChapter { ocean, land, sky, history, tech }

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
      GameChapter.tech => null,
    };

    if (chapter == GameChapter.tech) {
      final index = Chapter5TechValues.values.indexOf(value);
      if (index >= 0) {
        return Creature(
          value: value,
          name: Chapter5TechValues.names[index],
          imagePath: Chapter5TechValues.imagePaths[index],
        );
      }
    }

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

class Chapter5TechValues {
  static const values = [
    2, 4, 8, 16, 32, 64, 128, 256,
    512, 1024, 2048, 4096, 8192, 16384, 32768, 65536,
  ];

  static const names = [
    'Watch', 'Camera', 'Radio', 'Television',
    'Washing Machine', 'Refrigerator', 'Microwave', 'Game Controller',
    'Laptop', 'Smartphone', 'Tablet', 'Drone', 'VR Headset', 'Robot',
    'AI Core', 'Future Device',
  ];

  static const imagePaths = [
    'assets/creatures/chapter_05_modern_world/modern_02_watch.png',
    'assets/creatures/chapter_05_modern_world/modern_04_camera.png',
    'assets/creatures/chapter_05_modern_world/modern_08_radio.png',
    'assets/creatures/chapter_05_modern_world/modern_16_television.png',
    'assets/creatures/chapter_05_modern_world/modern_32_washing_machine.png',
    'assets/creatures/chapter_05_modern_world/modern_64_refrigerator.png',
    'assets/creatures/chapter_05_modern_world/modern_128_microwave.png',
    'assets/creatures/chapter_05_modern_world/modern_256_game_controller.png',
    'assets/creatures/chapter_05_modern_world/modern_512_laptop.png',
    'assets/creatures/chapter_05_modern_world/modern_1024_smartphone.png',
    'assets/creatures/chapter_05_modern_world/modern_2048_tablet.png',
    'assets/creatures/chapter_05_modern_world/modern_4096_drone.png',
    'assets/creatures/chapter_05_modern_world/modern_8192_vr_headset.png',
    'assets/creatures/chapter_05_modern_world/modern_16384_robot.png',
    'assets/creatures/chapter_05_modern_world/modern_32768_ai_core.png',
    'assets/creatures/chapter_05_modern_world/modern_65536_future_device.png',
  ];
}
