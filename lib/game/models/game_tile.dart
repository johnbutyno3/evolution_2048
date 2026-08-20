import 'creature.dart';

class GameTile {
  GameTile({required this.value});

  int value;

  Creature get creature =>
      Creature.fromValue(value) ??
      (throw StateError('Unsupported creature tile value: $value'));

  bool get isFinal => value == Creature.maxValue;

  bool get is2048 => value == 2048;

  void merge() {
    if (isFinal) {
      throw StateError('4096 is the final evolution stage.');
    }
    value *= 2;
  }
}
