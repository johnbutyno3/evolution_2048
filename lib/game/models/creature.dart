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
}

class Creature {
  const Creature({
    required this.value,
    required this.stage,
    required this.name,
  });

  final int value;
  final CreatureStage stage;
  final String name;

  static const List<Creature> chapter1Ocean = [
    Creature(value: 2, stage: CreatureStage.stage01, name: '矽藻'),
    Creature(value: 4, stage: CreatureStage.stage02, name: '鞭毛蟲'),
    Creature(value: 8, stage: CreatureStage.stage03, name: '磷蝦'),
    Creature(value: 16, stage: CreatureStage.stage04, name: '小丑魚'),
    Creature(value: 32, stage: CreatureStage.stage05, name: '水母'),
    Creature(value: 64, stage: CreatureStage.stage06, name: '魷魚'),
    Creature(value: 128, stage: CreatureStage.stage07, name: '海龜'),
    Creature(value: 256, stage: CreatureStage.stage08, name: '黃鰭鮪魚'),
    Creature(value: 512, stage: CreatureStage.stage09, name: '鯊魚'),
    Creature(value: 1024, stage: CreatureStage.stage10, name: '虎鯨'),
    Creature(value: 2048, stage: CreatureStage.stage11, name: '藍鯨'),
    Creature(value: 4096, stage: CreatureStage.stage12, name: '海底人類'),
  ];

  static const int maxValue = 4096;

  static Creature? fromValue(int value) {
    for (final creature in chapter1Ocean) {
      if (creature.value == value) return creature;
    }
    return null;
  }

  bool get isFinal => value == maxValue;
  bool get is2048 => value == 2048;
}
