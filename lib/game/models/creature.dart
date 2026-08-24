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

  // ============================================================
  // Chapter 1 - Ocean
  // ============================================================

  static const List<Creature> chapter1Ocean = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Diatom',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Flagellate',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Krill',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Clownfish',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Jellyfish',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Squid',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Ancient Deep-Sea Fish',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Deep-Sea Predator',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Large Marine Animal',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Ocean Apex Predator',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Yellowfin Tuna',
      imagePath:
          'assets/creatures/chapter_01_ocean/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Seabed Human',
      imagePath:
          'assets/creatures/chapter_01_ocean/future_seabed_human.png',
    ),
  ];

  // ============================================================
  // Chapter 2 - Land
  // ============================================================

  static const List<Creature> chapter2Land = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Primordial Land Life',
      imagePath:
          'assets/creatures/chapter_02_land/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Primitive Algae',
      imagePath:
          'assets/creatures/chapter_02_land/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Primitive Arthropod',
      imagePath:
          'assets/creatures/chapter_02_land/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Primitive Insect',
      imagePath:
          'assets/creatures/chapter_02_land/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Primitive Amphibian',
      imagePath:
          'assets/creatures/chapter_02_land/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Primitive Reptile',
      imagePath:
          'assets/creatures/chapter_02_land/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Primitive Mammal',
      imagePath:
          'assets/creatures/chapter_02_land/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Large Prehistoric Mammal',
      imagePath:
          'assets/creatures/chapter_02_land/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Primitive Primate',
      imagePath:
          'assets/creatures/chapter_02_land/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Early Human Ancestor',
      imagePath:
          'assets/creatures/chapter_02_land/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Homo Sapiens',
      imagePath:
          'assets/creatures/chapter_02_land/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Modern Human',
      imagePath:
          'assets/creatures/chapter_02_land/creature_4096.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'Evolved Future Human',
      imagePath:
          'assets/creatures/chapter_02_land/creature_8192.png',
    ),
  ];

  // ============================================================
  // Chapter 3 - Sky
  // ============================================================

  static const List<Creature> chapter3Sky = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Sky Microbe',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Airborne Microorganism',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Primitive Flying Insect',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Ancient Winged Insect',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Early Flying Reptile',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Pterosaur',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Primitive Bird',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Large Prehistoric Bird',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Raptor',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Eagle',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Giant Eagle',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Sky Apex Predator',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_4096.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'Legendary Flying Creature',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_8192.png',
    ),
    Creature(
      value: 16384,
      stage: CreatureStage.stage14,
      name: 'Celestial Lifeform',
      imagePath:
          'assets/creatures/chapter_03_sky/creature_16384.png',
    ),
  ];

  // ============================================================
  // Global
  // ============================================================

  static const int maxValue = 16384;

  static Creature? fromValue(int value) {
    for (final creature in chapter1Ocean) {
      if (creature.value == value) {
        return creature;
      }
    }

    return null;
  }

  static Creature? fromChapter2Value(int value) {
    for (final creature in chapter2Land) {
      if (creature.value == value) {
        return creature;
      }
    }

    return null;
  }

  static Creature? fromChapter3Value(int value) {
    for (final creature in chapter3Sky) {
      if (creature.value == value) {
        return creature;
      }
    }

    return null;
  }

  bool get isFinal => value == maxValue;

  bool get is2048 => value == 2048;

  bool get is4096 => value == 4096;

  bool get is8192 => value == 8192;
}