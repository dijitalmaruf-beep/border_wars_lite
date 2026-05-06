import 'dart:math';

class RandomUtils {
  RandomUtils({Random? random}) : _random = random ?? Random();

  final Random _random;

  bool chance(double probability) {
    if (probability <= 0) {
      return false;
    }
    if (probability >= 1) {
      return true;
    }
    return _random.nextDouble() < probability;
  }

  List<T> shuffled<T>(Iterable<T> values) {
    return List<T>.of(values)..shuffle(_random);
  }

  T pick<T>(List<T> values) {
    if (values.isEmpty) {
      throw StateError('Cannot pick from an empty list.');
    }
    return values[_random.nextInt(values.length)];
  }
}
