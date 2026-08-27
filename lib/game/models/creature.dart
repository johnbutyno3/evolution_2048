enum CreatureStage {
  stage01,
  stage02,
  stage03,
  stage04,
  stage05,
  stage06,
  stage07,
  stage08,
  stage09,
  stage10,
  stage11,
  stage12,
  stage13,
  stage14,
  stage15,
  stage16,
}

class Creature {
  const Creature({
    required this.value,
    required this.stage,
    required this.name,
    required this.imagePath,
  });

  final int value;
  final CreatureStage stage;
  final String name;
  final String imagePath;

  static const List<Creature> chapter1Ocean = [
    Creature(value: 2, stage: CreatureStage.stage01, name: 'Diatom', imagePath: 'assets/creatures/chapter_01_ocean/creature_02.png'),
    Creature(value: 4, stage: CreatureStage.stage02, name: 'Flagellate', imagePath: 'assets/creatures/chapter_01_ocean/creature_04.png'),
    Creature(value: 8, stage: CreatureStage.stage03, name: 'Krill', imagePath: 'assets/creatures/chapter_01_ocean/creature_08.png'),
    Creature(value: 16, stage: CreatureStage.stage04, name: 'Clownfish', imagePath: 'assets/creatures/chapter_01_ocean/creature_16.png'),
    Creature(value: 32, stage: CreatureStage.stage05, name: 'Jellyfish', imagePath: 'assets/creatures/chapter_01_ocean/creature_32.png'),
    Creature(value: 64, stage: CreatureStage.stage06, name: 'Squid', imagePath: 'assets/creatures/chapter_01_ocean/creature_64.png'),
    Creature(value: 128, stage: CreatureStage.stage07, name: 'Ancient Deep-Sea Fish', imagePath: 'assets/creatures/chapter_01_ocean/creature_128.png'),
    Creature(value: 256, stage: CreatureStage.stage08, name: 'Deep-Sea Predator', imagePath: 'assets/creatures/chapter_01_ocean/creature_256.png'),
    Creature(value: 512, stage: CreatureStage.stage09, name: 'Large Marine Animal', imagePath: 'assets/creatures/chapter_01_ocean/creature_512.png'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: 'Ocean Apex Predator', imagePath: 'assets/creatures/chapter_01_ocean/creature_1024.png'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: 'Yellowfin Tuna', imagePath: 'assets/creatures/chapter_01_ocean/creature_2048.png'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: 'Seabed Human', imagePath: 'assets/creatures/chapter_01_ocean/future_seabed_human.png'),
  ];

  static const List<Creature> chapter2Land = [
    Creature(value: 2, stage: CreatureStage.stage01, name: 'Primordial Land Life', imagePath: 'assets/creatures/chapter_02_land/creature_02.png'),
    Creature(value: 4, stage: CreatureStage.stage02, name: 'Primitive Algae', imagePath: 'assets/creatures/chapter_02_land/creature_04.png'),
    Creature(value: 8, stage: CreatureStage.stage03, name: 'Primitive Arthropod', imagePath: 'assets/creatures/chapter_02_land/creature_08.png'),
    Creature(value: 16, stage: CreatureStage.stage04, name: 'Primitive Insect', imagePath: 'assets/creatures/chapter_02_land/creature_16.png'),
    Creature(value: 32, stage: CreatureStage.stage05, name: 'Primitive Amphibian', imagePath: 'assets/creatures/chapter_02_land/creature_32.png'),
    Creature(value: 64, stage: CreatureStage.stage06, name: 'Primitive Reptile', imagePath: 'assets/creatures/chapter_02_land/creature_64.png'),
    Creature(value: 128, stage: CreatureStage.stage07, name: 'Primitive Mammal', imagePath: 'assets/creatures/chapter_02_land/creature_128.png'),
    Creature(value: 256, stage: CreatureStage.stage08, name: 'Large Prehistoric Mammal', imagePath: 'assets/creatures/chapter_02_land/creature_256.png'),
    Creature(value: 512, stage: CreatureStage.stage09, name: 'Primitive Primate', imagePath: 'assets/creatures/chapter_02_land/creature_512.png'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: 'Early Human Ancestor', imagePath: 'assets/creatures/chapter_02_land/creature_1024.png'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: 'Homo Sapiens', imagePath: 'assets/creatures/chapter_02_land/creature_2048.png'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: 'Modern Human', imagePath: 'assets/creatures/chapter_02_land/creature_4096.png'),
    Creature(value: 8192, stage: CreatureStage.stage13, name: 'Evolved Future Human', imagePath: 'assets/creatures/chapter_02_land/creature_8192.png'),
  ];

  static const List<Creature> chapter3Sky = [
    Creature(value: 2, stage: CreatureStage.stage01, name: 'Sky Microbe', imagePath: 'assets/creatures/chapter_03_sky/creature_02.png'),
    Creature(value: 4, stage: CreatureStage.stage02, name: 'Airborne Microorganism', imagePath: 'assets/creatures/chapter_03_sky/creature_04.png'),
    Creature(value: 8, stage: CreatureStage.stage03, name: 'Primitive Flying Insect', imagePath: 'assets/creatures/chapter_03_sky/creature_08.png'),
    Creature(value: 16, stage: CreatureStage.stage04, name: 'Ancient Winged Insect', imagePath: 'assets/creatures/chapter_03_sky/creature_16.png'),
    Creature(value: 32, stage: CreatureStage.stage05, name: 'Early Flying Reptile', imagePath: 'assets/creatures/chapter_03_sky/creature_32.png'),
    Creature(value: 64, stage: CreatureStage.stage06, name: 'Pterosaur', imagePath: 'assets/creatures/chapter_03_sky/creature_64.png'),
    Creature(value: 128, stage: CreatureStage.stage07, name: 'Primitive Bird', imagePath: 'assets/creatures/chapter_03_sky/creature_128.png'),
    Creature(value: 256, stage: CreatureStage.stage08, name: 'Large Prehistoric Bird', imagePath: 'assets/creatures/chapter_03_sky/creature_256.png'),
    Creature(value: 512, stage: CreatureStage.stage09, name: 'Raptor', imagePath: 'assets/creatures/chapter_03_sky/creature_512.png'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: 'Eagle', imagePath: 'assets/creatures/chapter_03_sky/creature_1024.png'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: 'Giant Eagle', imagePath: 'assets/creatures/chapter_03_sky/creature_2048.png'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: 'Sky Apex Predator', imagePath: 'assets/creatures/chapter_03_sky/creature_4096.png'),
    Creature(value: 8192, stage: CreatureStage.stage13, name: 'Legendary Flying Creature', imagePath: 'assets/creatures/chapter_03_sky/creature_8192.png'),
    Creature(value: 16384, stage: CreatureStage.stage14, name: 'Celestial Lifeform', imagePath: 'assets/creatures/chapter_03_sky/creature_16384.png'),
  ];

  static const List<Creature> chapter4History = [
    Creature(value: 2, stage: CreatureStage.stage01, name: 'Fire', imagePath: 'assets/creatures/chapter_04_history/history_02_fire.png'),
    Creature(value: 4, stage: CreatureStage.stage02, name: 'Civilization', imagePath: 'assets/creatures/chapter_04_history/history_04_civilization.png'),
    Creature(value: 8, stage: CreatureStage.stage03, name: 'Ancient Egypt', imagePath: 'assets/creatures/chapter_04_history/history_08_egypt.png'),
    Creature(value: 16, stage: CreatureStage.stage04, name: 'Rome', imagePath: 'assets/creatures/chapter_04_history/history_16_rome.png'),
    Creature(value: 32, stage: CreatureStage.stage05, name: 'Tang Dynasty', imagePath: 'assets/creatures/chapter_04_history/history_32_tang.png'),
    Creature(value: 64, stage: CreatureStage.stage06, name: 'Mongol Empire', imagePath: 'assets/creatures/chapter_04_history/history_64_mongol.png'),
    Creature(value: 128, stage: CreatureStage.stage07, name: 'Age of Exploration', imagePath: 'assets/creatures/chapter_04_history/history_128_exploration.png'),
    Creature(value: 256, stage: CreatureStage.stage08, name: 'Independence', imagePath: 'assets/creatures/chapter_04_history/history_256_independence.png'),
    Creature(value: 512, stage: CreatureStage.stage09, name: 'Industrial Revolution', imagePath: 'assets/creatures/chapter_04_history/history_512_industrial.png'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: 'Communication', imagePath: 'assets/creatures/chapter_04_history/history_1024_communication.png'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: 'Automobile', imagePath: 'assets/creatures/chapter_04_history/history_2048_automobile.png'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: 'Flight', imagePath: 'assets/creatures/chapter_04_history/history_4096_flight.png'),
    Creature(value: 8192, stage: CreatureStage.stage13, name: 'World War', imagePath: 'assets/creatures/chapter_04_history/history_8192_world_war.png'),
    Creature(value: 16384, stage: CreatureStage.stage14, name: 'Moon Landing', imagePath: 'assets/creatures/chapter_04_history/history_16384_moon.png'),
    Creature(value: 32768, stage: CreatureStage.stage15, name: 'Internet', imagePath: 'assets/creatures/chapter_04_history/history_32768_internet.png'),
  ];

  static const List<Creature> chapter5Tech = [
    Creature(value: 2, stage: CreatureStage.stage01, name: 'Watch', imagePath: 'assets/creatures/chapter_05_modern_world/modern_02_watch.png'),
    Creature(value: 4, stage: CreatureStage.stage02, name: 'Camera', imagePath: 'assets/creatures/chapter_05_modern_world/modern_04_camera.png'),
    Creature(value: 8, stage: CreatureStage.stage03, name: 'Radio', imagePath: 'assets/creatures/chapter_05_modern_world/modern_08_radio.png'),
    Creature(value: 16, stage: CreatureStage.stage04, name: 'Television', imagePath: 'assets/creatures/chapter_05_modern_world/modern_16_television.png'),
    Creature(value: 32, stage: CreatureStage.stage05, name: 'Washing Machine', imagePath: 'assets/creatures/chapter_05_modern_world/modern_32_washing_machine.png'),
    Creature(value: 64, stage: CreatureStage.stage06, name: 'Refrigerator', imagePath: 'assets/creatures/chapter_05_modern_world/modern_64_refrigerator.png'),
    Creature(value: 128, stage: CreatureStage.stage07, name: 'Microwave', imagePath: 'assets/creatures/chapter_05_modern_world/modern_128_microwave.png'),
    Creature(value: 256, stage: CreatureStage.stage08, name: 'Game Controller', imagePath: 'assets/creatures/chapter_05_modern_world/modern_256_game_controller.png'),
    Creature(value: 512, stage: CreatureStage.stage09, name: 'Laptop', imagePath: 'assets/creatures/chapter_05_modern_world/modern_512_laptop.png'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: 'Smartphone', imagePath: 'assets/creatures/chapter_05_modern_world/modern_1024_smartphone.png'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: 'Tablet', imagePath: 'assets/creatures/chapter_05_modern_world/modern_2048_tablet.png'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: 'Drone', imagePath: 'assets/creatures/chapter_05_modern_world/modern_4096_drone.png'),
    Creature(value: 8192, stage: CreatureStage.stage13, name: 'VR Headset', imagePath: 'assets/creatures/chapter_05_modern_world/modern_8192_vr_headset.png'),
    Creature(value: 16384, stage: CreatureStage.stage14, name: 'Robot', imagePath: 'assets/creatures/chapter_05_modern_world/modern_16384_robot.png'),
    Creature(value: 32768, stage: CreatureStage.stage15, name: 'AI Core', imagePath: 'assets/creatures/chapter_05_modern_world/modern_32768_ai_core.png'),
    Creature(value: 65536, stage: CreatureStage.stage16, name: 'Future Device', imagePath: 'assets/creatures/chapter_05_modern_world/modern_65536_future_device.png'),
  ];

  static const int maxValue = 65536;

  static Creature? fromValue(int value) => _find(chapter1Ocean, value);
  static Creature? fromChapter2Value(int value) => _find(chapter2Land, value);
  static Creature? fromChapter3Value(int value) => _find(chapter3Sky, value);
  static Creature? fromChapter4Value(int value) => _find(chapter4History, value);
  static Creature? fromChapter5Value(int value) => _find(chapter5Tech, value);

  static Creature? _find(List<Creature> list, int value) {
    for (final creature in list) {
      if (creature.value == value) return creature;
    }
    return null;
  }

  bool get isFinal => value == maxValue;
  bool get is2048 => value == 2048;
  bool get is4096 => value == 4096;
  bool get is8192 => value == 8192;
}
