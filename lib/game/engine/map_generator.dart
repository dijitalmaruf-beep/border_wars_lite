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

  static const _minimumColorDistance = 108.0;
  static const _atlasBotColorValue = 0xFF06B6D4;
  static const _novaBotColorValue = 0xFFC026D3;
  static const _terraBotColorValue = 0xFF65A30D;
  static const _botTemplates = <_BotTemplate>[
    _BotTemplate(
      id: 'atlas_bot',
      name: 'Atlas Bot',
      colorValue: _atlasBotColorValue,
      personality: BotPersonality.aggressive,
    ),
    _BotTemplate(
      id: 'nova_bot',
      name: 'Nova Bot',
      colorValue: _novaBotColorValue,
      personality: BotPersonality.opportunistic,
    ),
    _BotTemplate(
      id: 'terra_bot',
      name: 'Terra Bot',
      colorValue: _terraBotColorValue,
      personality: BotPersonality.defensive,
    ),
    _BotTemplate(
      id: 'orion_bot',
      name: 'Orion Bot',
      colorValue: 0xFFF59E0B,
      personality: BotPersonality.aggressive,
    ),
    _BotTemplate(
      id: 'vela_bot',
      name: 'Vela Bot',
      colorValue: 0xFF7C3AED,
      personality: BotPersonality.opportunistic,
    ),
    _BotTemplate(
      id: 'sol_bot',
      name: 'Sol Bot',
      colorValue: 0xFFE11D48,
      personality: BotPersonality.defensive,
    ),
    _BotTemplate(
      id: 'lyra_bot',
      name: 'Lyra Bot',
      colorValue: 0xFF2563EB,
      personality: BotPersonality.aggressive,
    ),
    _BotTemplate(
      id: 'aegis_bot',
      name: 'Aegis Bot',
      colorValue: 0xFF64748B,
      personality: BotPersonality.opportunistic,
    ),
    _BotTemplate(
      id: 'zenith_bot',
      name: 'Zenith Bot',
      colorValue: 0xFFEAB308,
      personality: BotPersonality.defensive,
    ),
  ];
  static const _fallbackBotColorValues = <int>[
    0xFF2563EB,
    0xFF16A34A,
    0xFFE11D48,
    0xFF7C3AED,
    0xFFF59E0B,
    0xFF06B6D4,
    0xFFC026D3,
    0xFFEAB308,
    0xFF65A30D,
    0xFF64748B,
    0xFFEA580C,
    0xFF0F766E,
    0xFF1E40AF,
    0xFF9F1239,
    0xFF78350F,
  ];

  GameState createInitialState({
    required String humanName,
    required int humanColorValue,
    int botCount = GameConstants.defaultBotPlayers,
    int? seed,
  }) {
    final players = createPlayers(
      humanName: humanName,
      humanColorValue: humanColorValue,
      botCount: botCount,
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
      turnStartedAtMillis: DateTime.now().millisecondsSinceEpoch,
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
    int botCount = GameConstants.defaultBotPlayers,
  }) {
    final cleanName = humanName.trim().isEmpty
        ? GameConstants.defaultHumanName
        : humanName.trim();
    final boundedBotCount = botCount
        .clamp(GameConstants.minBotPlayers, GameConstants.maxBotPlayers)
        .toInt();
    return <Player>[
      Player(
        id: GameConstants.humanPlayerId,
        name: cleanName,
        colorValue: humanColorValue,
        isBot: false,
      ),
      ...createBotPlayers(
        count: boundedBotCount,
        reservedColorValues: <int>{humanColorValue},
      ),
    ];
  }

  List<Player> createBotPlayers({
    required int count,
    int startIndex = 0,
    Set<int> reservedColorValues = const <int>{},
  }) {
    final boundedStartIndex = startIndex.clamp(0, _botTemplates.length).toInt();
    final availableCount = _botTemplates.length - boundedStartIndex;
    final boundedCount = count.clamp(0, availableCount).toInt();
    final usedColors = <int>{...reservedColorValues};

    return _botTemplates
        .skip(boundedStartIndex)
        .take(boundedCount)
        .map((bot) {
          final colorValue = _distinctColor(bot.colorValue, usedColors);
          usedColors.add(colorValue);
          return Player(
            id: bot.id,
            name: bot.name,
            colorValue: colorValue,
            isBot: true,
            botPersonality: bot.personality,
          );
        })
        .toList(growable: false);
  }

  int _distinctColor(int preferredColor, Set<int> usedColors) {
    if (!_isTooCloseToAny(preferredColor, usedColors)) {
      return preferredColor;
    }

    var bestColor = preferredColor;
    var bestDistance = -1.0;
    final candidates = <int>{preferredColor, ..._fallbackBotColorValues};
    for (final candidateColor in candidates) {
      final distance = _minimumDistanceToUsed(candidateColor, usedColors);
      if (distance > bestDistance) {
        bestDistance = distance;
        bestColor = candidateColor;
      }
    }
    return bestColor;
  }

  bool _isTooCloseToAny(int candidateColor, Set<int> usedColors) {
    return usedColors.any(
      (usedColor) =>
          _colorDistance(candidateColor, usedColor) < _minimumColorDistance,
    );
  }

  double _minimumDistanceToUsed(int candidateColor, Set<int> usedColors) {
    if (usedColors.isEmpty) {
      return double.infinity;
    }
    return usedColors
        .map((usedColor) => _colorDistance(candidateColor, usedColor))
        .reduce(min);
  }

  double _colorDistance(int leftColor, int rightColor) {
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

class _BotTemplate {
  const _BotTemplate({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.personality,
  });

  final String id;
  final String name;
  final int colorValue;
  final BotPersonality personality;
}
