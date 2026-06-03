import 'package:chroma_conquest/core/constants/app_colors.dart';
import 'package:chroma_conquest/core/constants/game_constants.dart';
import 'package:chroma_conquest/game/engine/map_generator.dart';
import 'package:chroma_conquest/game/engine/reinforcement_calculator.dart';
import 'package:chroma_conquest/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ReinforcementCalculator();
  const generator = MapGenerator();

  GameState stateWithContinentsOwned(
    List<String> continents,
    String playerId, {
    String? missingTerritoryId,
  }) {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 9,
    );

    return state.copyWith(
      territories: state.territories.map((territory) {
        if (territory.id == missingTerritoryId) {
          return territory.copyWith(ownerId: null);
        }
        if (continents.contains(territory.continent)) {
          return territory.copyWith(ownerId: playerId);
        }
        return territory.copyWith(ownerId: null);
      }).toList(),
    );
  }

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

  test('no full continent gives no bonus', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 9,
    );
    final breakdown = calculator.breakdownForPlayer(
      state,
      GameConstants.humanPlayerId,
    );

    expect(breakdown.continentBonus, 0);
    expect(breakdown.total, breakdown.base);
  });

  test('full continent controlled adds bonus', () {
    final state = stateWithContinentsOwned(const <String>[
      'South America',
    ], GameConstants.humanPlayerId);
    final breakdown = calculator.breakdownForPlayer(
      state,
      GameConstants.humanPlayerId,
    );

    expect(breakdown.continentBonus, 3);
    expect(breakdown.controlledContinents.first.continent, 'South America');
    expect(breakdown.total, breakdown.base + 3);
  });

  test('losing one territory removes continent bonus', () {
    final southAmericaTerritoryId = generator
        .createInitialState(
          humanName: 'Alex',
          humanColorValue: AppColors.humanBlueValue,
          seed: 9,
        )
        .territories
        .firstWhere((territory) => territory.continent == 'South America')
        .id;
    final state = stateWithContinentsOwned(
      const <String>['South America'],
      GameConstants.humanPlayerId,
      missingTerritoryId: southAmericaTerritoryId,
    );
    final breakdown = calculator.breakdownForPlayer(
      state,
      GameConstants.humanPlayerId,
    );

    expect(breakdown.continentBonus, 0);
    expect(breakdown.controlledContinents, isEmpty);
  });

  test('multiple continent bonuses stack', () {
    final state = stateWithContinentsOwned(const <String>[
      'South America',
      'Oceania',
    ], GameConstants.humanPlayerId);
    final breakdown = calculator.breakdownForPlayer(
      state,
      GameConstants.humanPlayerId,
    );

    expect(breakdown.continentBonus, 5);
    expect(
      breakdown.controlledContinents.map((bonus) => bonus.continent),
      containsAll(<String>['South America', 'Oceania']),
    );
  });

  test('owning Anatolia adds strategic bonus', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 9,
    );
    final anatoliaState = state.copyWith(
      territories: state.territories.map((territory) {
        if (territory.id == 'anatolia') {
          return territory.copyWith(ownerId: GameConstants.humanPlayerId);
        }
        return territory.copyWith(ownerId: null);
      }).toList(),
    );
    final breakdown = calculator.breakdownForPlayer(
      anatoliaState,
      GameConstants.humanPlayerId,
    );

    expect(breakdown.continentBonus, 3);
    expect(
      breakdown.controlledContinents.map((bonus) => bonus.continent),
      contains('Anatolia'),
    );
  });

  test('bots use difficulty-adjusted reinforcement formula', () {
    final state = stateWithContinentsOwned(const <String>['Asia'], 'atlas_bot');
    final breakdown = calculator.breakdownForPlayer(state, 'atlas_bot');

    expect(breakdown.continentBonus, 10);
    expect(breakdown.difficultyBonus, greaterThan(0));
    expect(calculator.calculateForPlayer(state, 'atlas_bot'), breakdown.total);
  });

  test('hard difficulty gives bots a larger reinforcement bonus', () {
    final normal = stateWithContinentsOwned(const <String>[
      'Asia',
    ], 'atlas_bot');
    final hard = normal.copyWith(difficulty: GameDifficulty.hard);

    expect(
      calculator.breakdownForPlayer(hard, 'atlas_bot').difficultyBonus,
      greaterThan(
        calculator.breakdownForPlayer(normal, 'atlas_bot').difficultyBonus,
      ),
    );
  });
}
