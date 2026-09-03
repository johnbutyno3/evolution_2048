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
  stage17,
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
      imagePath: 'assets/creatures/chapter_01_ocean/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Flagellate',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Krill',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Clownfish',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Jellyfish',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Squid',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Sea Turtle',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Yellowfin Tuna',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Shark',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Orca',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Blue Whale',
      imagePath: 'assets/creatures/chapter_01_ocean/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Seabed Human',
      imagePath: 'assets/creatures/chapter_01_ocean/future_seabed_human.png',
    ),
  ];

  // ============================================================
  // Chapter 2 - Land
  // ============================================================

  static const List<Creature> chapter2Land = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Land Plant',
      imagePath: 'assets/creatures/chapter_02_land/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Fern',
      imagePath: 'assets/creatures/chapter_02_land/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Arthropod',
      imagePath: 'assets/creatures/chapter_02_land/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Insect',
      imagePath: 'assets/creatures/chapter_02_land/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Amphibian',
      imagePath: 'assets/creatures/chapter_02_land/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Reptile',
      imagePath: 'assets/creatures/chapter_02_land/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Small Mammal',
      imagePath: 'assets/creatures/chapter_02_land/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Large Mammal',
      imagePath: 'assets/creatures/chapter_02_land/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Primate',
      imagePath: 'assets/creatures/chapter_02_land/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Early Human',
      imagePath: 'assets/creatures/chapter_02_land/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Homo Sapiens',
      imagePath: 'assets/creatures/chapter_02_land/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Civilized Human',
      imagePath: 'assets/creatures/chapter_02_land/creature_4096.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'Future Human',
      imagePath: 'assets/creatures/chapter_02_land/creature_8192.png',
    ),
  ];

  // ============================================================
  // Chapter 3 - Sky
  // ============================================================

  static const List<Creature> chapter3Sky = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Hairy Cell Organism',
      imagePath: 'assets/creatures/chapter_03_sky/creature_02.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Mosquito',
      imagePath: 'assets/creatures/chapter_03_sky/creature_04.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Dragonfly',
      imagePath: 'assets/creatures/chapter_03_sky/creature_08.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Archaeopteryx',
      imagePath: 'assets/creatures/chapter_03_sky/creature_16.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Eagle',
      imagePath: 'assets/creatures/chapter_03_sky/creature_32.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Pterosaur',
      imagePath: 'assets/creatures/chapter_03_sky/creature_64.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Bat',
      imagePath: 'assets/creatures/chapter_03_sky/creature_128.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Glider',
      imagePath: 'assets/creatures/chapter_03_sky/creature_256.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Early Aircraft',
      imagePath: 'assets/creatures/chapter_03_sky/creature_512.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Jet Fighter',
      imagePath: 'assets/creatures/chapter_03_sky/creature_1024.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Stealth Fighter',
      imagePath: 'assets/creatures/chapter_03_sky/creature_2048.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Aircraft',
      imagePath: 'assets/creatures/chapter_03_sky/creature_4096.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'Wing Suit',
      imagePath: 'assets/creatures/chapter_03_sky/creature_8192.png',
    ),
    Creature(
      value: 16384,
      stage: CreatureStage.stage14,
      name: 'Winged Human',
      imagePath: 'assets/creatures/chapter_03_sky/creature_16384.png',
    ),
  ];

  // ============================================================
  // Chapter 4 - History
  // ============================================================

  static const List<Creature> chapter4History = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Fire',
      imagePath: 'assets/creatures/chapter_04_history/history_02_fire.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Wall',
      imagePath:
          'assets/creatures/chapter_04_history/history_04_civilization.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Pyramid',
      imagePath: 'assets/creatures/chapter_04_history/history_08_egypt.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Roman Architecture',
      imagePath: 'assets/creatures/chapter_04_history/history_16_rome.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Tang Architecture',
      imagePath: 'assets/creatures/chapter_04_history/history_32_tang.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Mongol Invasion',
      imagePath: 'assets/creatures/chapter_04_history/history_64_mongol.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Age of Exploration',
      imagePath:
          'assets/creatures/chapter_04_history/history_128_exploration.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'American Independence',
      imagePath:
          'assets/creatures/chapter_04_history/history_256_independence.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Industrial Revolution',
      imagePath:
          'assets/creatures/chapter_04_history/history_512_industrial.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Communication Revolution',
      imagePath:
          'assets/creatures/chapter_04_history/history_1024_communication.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Automobile Invention',
      imagePath:
          'assets/creatures/chapter_04_history/history_2048_automobile.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Airplane Invention',
      imagePath: 'assets/creatures/chapter_04_history/history_4096_flight.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'World War II',
      imagePath:
          'assets/creatures/chapter_04_history/history_8192_world_war.png',
    ),
    Creature(
      value: 16384,
      stage: CreatureStage.stage14,
      name: 'Space Exploration',
      imagePath: 'assets/creatures/chapter_04_history/history_16384_moon.png',
    ),
    Creature(
      value: 32768,
      stage: CreatureStage.stage15,
      name: 'Information Age',
      imagePath:
          'assets/creatures/chapter_04_history/history_32768_internet.png',
    ),
  ];

  // ============================================================
  // Chapter 5 - Technology
  // ============================================================

  static const List<Creature> chapter5Tech = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Watch',
      imagePath: 'assets/creatures/chapter_05_modern_world/modern_02_watch.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'Camera',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_04_camera.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Radio',
      imagePath: 'assets/creatures/chapter_05_modern_world/modern_08_radio.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Television',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_16_television.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Washing Machine',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_32_washing_machine.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Refrigerator',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_64_refrigerator.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Microwave',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_128_microwave.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Remote Control',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_256_game_controller.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Computer',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_512_laptop.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Mobile Phone',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_1024_smartphone.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Tablet',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_2048_tablet.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'Drone',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_4096_drone.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'VR Device',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_8192_vr_headset.png',
    ),
    Creature(
      value: 16384,
      stage: CreatureStage.stage14,
      name: 'Robot',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_16384_robot.png',
    ),
    Creature(
      value: 32768,
      stage: CreatureStage.stage15,
      name: 'Chip',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_32768_ai_core.png',
    ),
    Creature(
      value: 65536,
      stage: CreatureStage.stage16,
      name: 'Future Technology',
      imagePath:
          'assets/creatures/chapter_05_modern_world/modern_65536_future_device.png',
    ),
  ];

  // ============================================================
  // Chapter 6 - Universe
  // ============================================================

  static const List<Creature> chapter6Universe = [
    Creature(
      value: 2,
      stage: CreatureStage.stage01,
      name: 'Atom',
      imagePath: 'assets/creatures/chapter_06_universe/universe_2_atom.png',
    ),
    Creature(
      value: 4,
      stage: CreatureStage.stage02,
      name: 'New Star Formation',
      imagePath: 'assets/creatures/chapter_06_universe/universe_4_star.png',
    ),
    Creature(
      value: 8,
      stage: CreatureStage.stage03,
      name: 'Planet',
      imagePath: 'assets/creatures/chapter_06_universe/universe_8_planet.png',
    ),
    Creature(
      value: 16,
      stage: CreatureStage.stage04,
      name: 'Earth',
      imagePath: 'assets/creatures/chapter_06_universe/universe_16_earth.png',
    ),
    Creature(
      value: 32,
      stage: CreatureStage.stage05,
      name: 'Moon Visit',
      imagePath: 'assets/creatures/chapter_06_universe/universe_32_moon.png',
    ),
    Creature(
      value: 64,
      stage: CreatureStage.stage06,
      name: 'Communication Satellite',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_64_space_probe.png',
    ),
    Creature(
      value: 128,
      stage: CreatureStage.stage07,
      name: 'Space Station',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_128_space_colony.png',
    ),
    Creature(
      value: 256,
      stage: CreatureStage.stage08,
      name: 'Planet Mining',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_256_asteroid_mining.png',
    ),
    Creature(
      value: 512,
      stage: CreatureStage.stage09,
      name: 'Solar System Challenge',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_512_solar_expansion.png',
    ),
    Creature(
      value: 1024,
      stage: CreatureStage.stage10,
      name: 'Alien Life',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_1024_alien_life.png',
    ),
    Creature(
      value: 2048,
      stage: CreatureStage.stage11,
      name: 'Alien',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_2048_alien_intelligence.png',
    ),
    Creature(
      value: 4096,
      stage: CreatureStage.stage12,
      name: 'First Contact',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_4096_first_contact.png',
    ),
    Creature(
      value: 8192,
      stage: CreatureStage.stage13,
      name: 'Unified Exploration',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_8192_interstellar_travel.png',
    ),
    Creature(
      value: 16384,
      stage: CreatureStage.stage14,
      name: 'Galactic Voyage',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_16384_galaxy_exploration.png',
    ),
    Creature(
      value: 32768,
      stage: CreatureStage.stage15,
      name: 'Visit Alien Civilization',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_32768_cosmic_civilization.png',
    ),
    Creature(
      value: 65536,
      stage: CreatureStage.stage16,
      name: 'Return to Maintain Earth',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_65536_earth_development.png',
    ),
    Creature(
      value: 131072,
      stage: CreatureStage.stage17,
      name: 'God Hand',
      imagePath:
          'assets/creatures/chapter_06_universe/universe_131072_god_perspective.png',
    ),
  ];

  // ============================================================
  // Global
  // ============================================================

  static const int maxValue = 131072;

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

  static Creature? fromChapter4Value(int value) {
    for (final creature in chapter4History) {
      if (creature.value == value) {
        return creature;
      }
    }
    return null;
  }

  static Creature? fromChapter5Value(int value) {
    for (final creature in chapter5Tech) {
      if (creature.value == value) {
        return creature;
      }
    }
    return null;
  }

  static Creature? fromChapter6Value(int value) {
    for (final creature in chapter6Universe) {
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
