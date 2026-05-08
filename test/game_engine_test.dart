import 'package:border_wars_lite/core/constants/app_colors.dart';
import 'package:border_wars_lite/core/constants/game_constants.dart';
import 'package:border_wars_lite/game/engine/game_engine.dart';
import 'package:border_wars_lite/game/engine/map_generator.dart';
import 'package:border_wars_lite/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = MapGenerator();
  const engine = GameEngine();

  GameState newState() {
    return generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
    );
  }

  test('assigns starting and neutral territories for a new game', () {
    final state = newState();

    expect(state.players, hasLength(4));
    expect(state.territories, hasLength(GameConstants.totalTerritories));

    for (final player in state.players) {
      final owned = state.territoriesOwnedBy(player.id);
      expect(owned, hasLength(GameConstants.startingTerritoriesPerPlayer));
      expect(
        owned.map((territory) => territory.armyCount),
        everyElement(GameConstants.startingArmies),
      );
    }

    final neutralTerritories = state.territories
        .where((territory) => territory.ownerId == null)
        .toList();
    expect(
      neutralTerritories,
      hasLength(
        GameConstants.totalTerritories -
            state.players.length * GameConstants.startingTerritoriesPerPlayer,
      ),
    );
    expect(
      neutralTerritories.map((territory) => territory.armyCount),
      everyElement(GameConstants.neutralArmies),
    );
  });

  test(
    'validates attacks by ownership, armies, neighbor, and target owner',
    () {
      final state = newState().copyWith(
        phase: GamePhase.attack,
        remainingReinforcements: 0,
      );

      expect(
        engine.canAttack(state, sourceId: 'western_us', targetId: 'central_us'),
        isTrue,
      );
      expect(
        engine.canAttack(state, sourceId: 'western_us', targetId: 'greenland'),
        isFalse,
      );
      expect(
        engine.canAttack(state, sourceId: 'central_us', targetId: 'western_us'),
        isFalse,
      );

      final weakSourceState = state.copyWith(
        territories: state.territories.map((territory) {
          if (territory.id == 'western_us') {
            return territory.copyWith(armyCount: 1);
          }
          return territory;
        }).toList(),
      );

      expect(
        engine.canAttack(
          weakSourceState,
          sourceId: 'western_us',
          targetId: 'central_us',
        ),
        isFalse,
      );
    },
  );

  test('does not select non-neighbor attack targets', () {
    final state = newState().copyWith(
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      selectedSourceId: 'western_us',
    );

    final nextState = engine.selectTerritory(state, 'middle_east');

    expect(nextState.selectedSourceId, 'western_us');
    expect(nextState.selectedTargetId, isNull);
    expect(
      nextState.statusMessage,
      'Only neighboring enemy territories can be attacked.',
    );
  });

  test('selects only valid neighboring attack targets', () {
    final state = newState().copyWith(
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      selectedSourceId: 'western_us',
    );

    final nextState = engine.selectTerritory(state, 'central_us');

    expect(nextState.selectedSourceId, 'western_us');
    expect(nextState.selectedTargetId, 'central_us');
    expect(nextState.statusMessage, 'Attack route ready.');
  });

  test('detects victory at seventy percent territory control', () {
    final state = newState();
    final requiredTerritories =
        (state.territories.length * GameConstants.victoryTerritoryRatio).ceil();
    final conqueredState = state.copyWith(
      territories: state.territories.asMap().entries.map((entry) {
        return entry.value.copyWith(
          ownerId: entry.key < requiredTerritories
              ? GameConstants.humanPlayerId
              : null,
        );
      }).toList(),
    );

    expect(engine.findWinner(conqueredState), GameConstants.humanPlayerId);
  });

  test('detects victory when only one non-neutral player remains', () {
    final state = newState();
    final soloState = state.copyWith(
      territories: state.territories.map((territory) {
        return territory.copyWith(
          ownerId: territory.ownerId == GameConstants.humanPlayerId
              ? GameConstants.humanPlayerId
              : null,
        );
      }).toList(),
    );

    expect(engine.findWinner(soloState), GameConstants.humanPlayerId);
  });
}
