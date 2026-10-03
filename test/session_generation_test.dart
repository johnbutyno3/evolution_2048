import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/services/session_generation.dart';

void main() {
  test('a stale refresh generation cannot commit after reset takes ownership', () {
    final ownership = SessionGeneration();
    final refreshGeneration = ownership.current;

    ownership.begin();

    expect(ownership.isCurrent(refreshGeneration), isFalse);
  });

  test('the current generation remains valid until a newer session operation begins', () {
    final ownership = SessionGeneration();
    final generation = ownership.begin();

    expect(ownership.isCurrent(generation), isTrue);

    ownership.begin();

    expect(ownership.isCurrent(generation), isFalse);
  });
}
