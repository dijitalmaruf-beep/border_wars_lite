import 'dart:math';

import 'package:border_wars_lite/core/constants/app_colors.dart';
import 'package:border_wars_lite/core/constants/game_constants.dart';
import 'package:border_wars_lite/game/data/sample_world_map.dart';
import 'package:border_wars_lite/game/engine/map_generator.dart';
import 'package:border_wars_lite/game/models/bot_personality.dart';
import 'package:border_wars_lite/game/models/game_state.dart';
import 'package:border_wars_lite/game/models/player.dart';
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

  double colorDistance(int leftColor, int rightColor) {
    final leftRed = (leftColor >> 16) & 0xFF;
    final leftGreen = (leftColor >> 8) & 0xFF;
    final leftBlue = leftColor & 0xFF;
    final rightRed = (rightColor >> 16) & 0xFF;
    final rightGreen = (rightColor >> 8) & 0xFF;
    final rightBlue = rightColor & 0xFF;
    final redDelta = leftRed - rightRed;
    final greenDelta = leftGreen - rightGreen;
    final blueDelta = leftBlue - rightBlue;
    return sqrt(
      redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta,
    );
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

  test('custom bot count creates requested bot opponents', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      botCount: 7,
      seed: 44,
    );

    expect(state.players.where((player) => player.isBot), hasLength(7));
    expect(state.players, hasLength(8));
    for (final player in state.players) {
      expect(
        state.territoriesOwnedBy(player.id),
        hasLength(GameConstants.startingTerritoriesPerPlayer),
      );
    }
  });

  test('bot count is clamped to supported range', () {
    final highBotState = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      botCount: 99,
      seed: 45,
    );
    final lowBotState = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      botCount: 0,
      seed: 46,
    );

    expect(
      highBotState.players.where((player) => player.isBot),
      hasLength(GameConstants.maxBotPlayers),
    );
    expect(
      lowBotState.players.where((player) => player.isBot),
      hasLength(GameConstants.minBotPlayers),
    );
  });

  test('bot colors avoid exact conflict with selected human color', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.atlasBotValue,
      botCount: 5,
      seed: 47,
    );
    final colorValues = state.players.map((player) => player.colorValue);

    expect(colorValues.toSet(), hasLength(state.players.length));
  });

  test('max bot palette keeps player colors visibly separated', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanGoldValue,
      botCount: GameConstants.maxBotPlayers,
      seed: 48,
    );
    final colorValues = state.players
        .map((player) => player.colorValue)
        .toList(growable: false);

    for (var left = 0; left < colorValues.length; left += 1) {
      for (var right = left + 1; right < colorValues.length; right += 1) {
        expect(
          colorDistance(colorValues[left], colorValues[right]),
          greaterThanOrEqualTo(65),
        );
      }
    }
  });

  test('custom online players receive balanced starting territories', () {
    final state = generator.createInitialStateForPlayers(
      players: const <Player>[
        Player(
          id: 'human',
          name: 'Host',
          colorValue: AppColors.humanBlueValue,
          isBot: false,
        ),
        Player(
          id: 'atlas_bot',
          name: 'Guest',
          colorValue: AppColors.atlasBotValue,
          isBot: false,
        ),
        Player(
          id: 'nova_bot',
          name: 'Nova Bot',
          colorValue: AppColors.novaBotValue,
          isBot: true,
          botPersonality: BotPersonality.opportunistic,
        ),
        Player(
          id: 'terra_bot',
          name: 'Terra Bot',
          colorValue: AppColors.terraBotValue,
          isBot: true,
          botPersonality: BotPersonality.defensive,
        ),
      ],
      gameId: 'ABC123',
      firstPlayerId: 'human',
      seed: 51,
    );

    expect(state.id, 'ABC123');
    expect(state.players.where((player) => !player.isBot), hasLength(2));
    for (final player in state.players) {
      expect(
        state.territoriesOwnedBy(player.id),
        hasLength(GameConstants.startingTerritoriesPerPlayer),
      );
    }
  });
}
