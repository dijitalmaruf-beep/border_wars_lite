import 'package:border_wars_lite/game/engine/reinforcement_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ReinforcementCalculator();

  test('uses a minimum of three reinforcements', () {
    expect(calculator.calculateForOwnedTerritories(0), 3);
    expect(calculator.calculateForOwnedTerritories(3), 3);
    expect(calculator.calculateForOwnedTerritories(8), 3);
  });

  test('scales reinforcements by owned territory count', () {
    expect(calculator.calculateForOwnedTerritories(9), 3);
    expect(calculator.calculateForOwnedTerritories(12), 4);
    expect(calculator.calculateForOwnedTerritories(21), 7);
  });
}
