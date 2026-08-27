import 'game_tile.dart';

/// Chapter 5: Technology Era configuration.
class Chapter5TechConfig {
  static const int targetValue = 65536;

  static const List<int> values = [
    2,
    4,
    8,
    16,
    32,
    64,
    128,
    256,
    512,
    1024,
    2048,
    4096,
    8192,
    16384,
    32768,
    65536,
  ];

  static const List<String> imagePaths = [
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

  static GameTile tile(int value) =>
      GameTile(value: value, chapter: GameChapter.tech);
}
