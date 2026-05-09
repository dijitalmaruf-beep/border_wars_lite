import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../data/sample_world_map.dart';
import '../models/bot_personality.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'reinforcement_calculator.dart';

class MapGenerator {
  const MapGenerator({
    this.reinforcementCalculator = const ReinforcementCalculator(),
  });

  final ReinforcementCalculator reinforcementCalculator;

  static const _atlasBotColorValue = 0xFF0891B2;
  static const _novaBotColorValue = 0xFFBE185D;
  static const _terraBotColorValue = 0xFF65A30D;

  GameState createInitialState({
    required String humanName,
    required int humanColorValue,
    int? seed,
  }) {
    final players = createPlayers(
      humanName: humanName,
      humanColorValue: humanColorValue,
    );
    return createInitialStateForPlayers(
      players: players,
      gameId: 'local-${DateTime.now().millisecondsSinceEpoch}',
      firstPlayerId: GameConstants.humanPlayerId,
      seed: seed,
    );
  }

  GameState createInitialStateForPlayers({
    required List<Player> players,
    required String gameId,
    required String firstPlayerId,
    int? seed,
  }) {
    final random = seed == null ? Random() : Random(seed);
    final startingOwners = _startingTerritoryOwners(players, random);
    final territories = sampleWorldTerritories.map((territory) {
      final ownerId = startingOwners[territory.id];
      return territory.copyWith(
        ownerId: ownerId,
        armyCount: ownerId == null
            ? GameConstants.neutralArmies
            : GameConstants.startingArmies,
      );
    }).toList();
    final firstPlayerIndex = players.indexWhere(
      (player) => player.id == firstPlayerId,
    );
    final currentPlayerIndex = firstPlayerIndex < 0 ? 0 : firstPlayerIndex;

    final initialState = GameState(
      id: gameId,
      players: players,
      territories: territories,
      currentPlayerIndex: currentPlayerIndex,
      phase: GamePhase.reinforce,
      remainingReinforcements: 0,
      selectedSourceId: null,
      selectedTargetId: null,
      turnNumber: 1,
      statusMessage: 'Choose a territory to reinforce.',
    );

    return initialState.copyWith(
      remainingReinforcements: reinforcementCalculator.calculateForPlayer(
        initialState,
        initialState.currentPlayer.id,
      ),
    );
  }

  List<Player> createPlayers({
    required String humanName,
    required int humanColorValue,
  }) {
    final cleanName = humanName.trim().isEmpty
        ? GameConstants.defaultHumanName
        : humanName.trim();
    return <Player>[
      Player(
        id: GameConstants.humanPlayerId,
        name: cleanName,
        colorValue: humanColorValue,
        isBot: false,
      ),
      const Player(
        id: 'atlas_bot',
        name: 'Atlas Bot',
        colorValue: _atlasBotColorValue,
        isBot: true,
        botPersonality: BotPersonality.aggressive,
      ),
      const Player(
        id: 'nova_bot',
        name: 'Nova Bot',
        colorValue: _novaBotColorValue,
        isBot: true,
        botPersonality: BotPersonality.opportunistic,
      ),
      const Player(
        id: 'terra_bot',
        name: 'Terra Bot',
        colorValue: _terraBotColorValue,
        isBot: true,
        botPersonality: BotPersonality.defensive,
      ),
    ];
  }

  Map<String, String> _startingTerritoryOwners(
    List<Player> players,
    Random random,
  ) {
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final assignment = _balancedStartingTerritoryOwners(players, random);
      if (_hasExpectedStartingCounts(assignment, players)) {
        return assignment;
      }
    }
    return _fallbackStartingTerritoryOwners(players, random);
  }

  Map<String, String> _balancedStartingTerritoryOwners(
    List<Player> players,
    Random random,
  ) {
    final continentPools = <String, List<String>>{};
    for (final territory in sampleWorldTerritories) {
      continentPools
          .putIfAbsent(territory.continent, () => <String>[])
          .add(territory.id);
    }

    for (final pool in continentPools.values) {
      pool.shuffle(random);
    }

    final continents = continentPools.keys.toList()..shuffle(random);
    final usedContinentsByPlayer = <String, Set<String>>{
      for (final player in players) player.id: <String>{},
    };
    final assignment = <String, String>{};

    for (
      var round = 0;
      round < GameConstants.startingTerritoriesPerPlayer;
      round += 1
    ) {
      final playerOrder = <Player>[
        ...players.skip(round % players.length),
        ...players.take(round % players.length),
      ];

      for (final player in playerOrder) {
        final continent = _chooseStartingContinent(
          continents,
          continentPools,
          usedContinentsByPlayer[player.id]!,
        );
        if (continent == null) {
          return assignment;
        }

        final territoryId = continentPools[continent]!.removeLast();
        assignment[territoryId] = player.id;
        usedContinentsByPlayer[player.id]!.add(continent);
      }
    }

    return assignment;
  }

  String? _chooseStartingContinent(
    List<String> continents,
    Map<String, List<String>> continentPools,
    Set<String> usedContinents,
  ) {
    for (final continent in continents) {
      if (!usedContinents.contains(continent) &&
          (continentPools[continent]?.isNotEmpty ?? false)) {
        return continent;
      }
    }

    for (final continent in continents) {
      if (continentPools[continent]?.isNotEmpty ?? false) {
        return continent;
      }
    }

    return null;
  }

  bool _hasExpectedStartingCounts(
    Map<String, String> assignment,
    List<Player> players,
  ) {
    if (assignment.length !=
        players.length * GameConstants.startingTerritoriesPerPlayer) {
      return false;
    }
    for (final player in players) {
      final count = assignment.values
          .where((playerId) => playerId == player.id)
          .length;
      if (count != GameConstants.startingTerritoriesPerPlayer) {
        return false;
      }
    }
    return true;
  }

  Map<String, String> _fallbackStartingTerritoryOwners(
    List<Player> players,
    Random random,
  ) {
    final territoryIds =
        sampleWorldTerritories.map((territory) => territory.id).toList()
          ..shuffle(random);
    final assignment = <String, String>{};
    var territoryIndex = 0;
    for (
      var round = 0;
      round < GameConstants.startingTerritoriesPerPlayer;
      round += 1
    ) {
      for (final player in players) {
        assignment[territoryIds[territoryIndex]] = player.id;
        territoryIndex += 1;
      }
    }
    return assignment;
  }
}
