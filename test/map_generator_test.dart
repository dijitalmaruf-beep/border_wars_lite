import 'package:border_wars_lite/core/constants/app_colors.dart';
import 'package:border_wars_lite/core/constants/game_constants.dart';
import 'package:border_wars_lite/game/data/sample_world_map.dart';
import 'package:border_wars_lite/game/engine/map_generator.dart';
import 'package:border_wars_lite/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = MapGenerator();

  GameState newState(int seed) {
    return generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: seed,
    );
  }

  Map<String, String> startingAssignment(GameState state) {
    return <String, String>{
      for (final territory in state.territories)
        if (territory.ownerId != null) territory.id: territory.ownerId!,
    };
  }

  test('same seed produces same assignment', () {
    expect(startingAssignment(newState(11)), startingAssignment(newState(11)));
  });

  test('different seeds produce different assignments', () {
    expect(
      startingAssignment(newState(11)),
      isNot(startingAssignment(newState(12))),
    );
  });

  test('each player gets exactly three starting territories', () {
    final state = newState(21);

    for (final player in state.players) {
      expect(
        state.territoriesOwnedBy(player.id),
        hasLength(GameConstants.startingTerritoriesPerPlayer),
      );
    }
  });

  test('starting territories are unique playable territories', () {
    final state = newState(31);
    final assignedTerritoryIds = startingAssignment(state).keys.toList();
    final playableTerritoryIds = sampleWorldTerritories
        .map((territory) => territory.id)
        .toSet();

    expect(
      assignedTerritoryIds.toSet(),
      hasLength(assignedTerritoryIds.length),
    );
    expect(assignedTerritoryIds.every(playableTerritoryIds.contains), isTrue);
  });

  test('neutral territories remain neutral', () {
    final state = newState(41);
    final assignedCount =
        state.players.length * GameConstants.startingTerritoriesPerPlayer;
    final neutralTerritories = state.territories
        .where((territory) => territory.ownerId == null)
        .toList(growable: false);

    expect(
      neutralTerritories,
      hasLength(state.territories.length - assignedCount),
    );
    expect(
      neutralTerritories.map((territory) => territory.armyCount),
      everyElement(GameConstants.neutralArmies),
    );
  });
}
