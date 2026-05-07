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
  }) {
    final players = createPlayers(
      humanName: humanName,
      humanColorValue: humanColorValue,
    );
    final startingOwners = _startingTerritoryOwners(players);
    final territories = sampleWorldTerritories.map((territory) {
      final ownerId = startingOwners[territory.id];
      return territory.copyWith(
        ownerId: ownerId,
        armyCount: ownerId == null
            ? GameConstants.neutralArmies
            : GameConstants.startingArmies,
      );
    }).toList();

    final initialState = GameState(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      players: players,
      territories: territories,
      currentPlayerIndex: 0,
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
        GameConstants.humanPlayerId,
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

  Map<String, String> _startingTerritoryOwners(List<Player> players) {
    final assignments = <String, List<String>>{
      players[0].id: const ['western_us', 'western_europe', 'australia_east'],
      players[1].id: const ['eastern_canada', 'north_africa', 'china_north'],
      players[2].id: const ['brazil', 'siberia', 'india'],
      players[3].id: const ['eastern_us', 'southern_africa', 'indonesia'],
    };

    return <String, String>{
      for (final entry in assignments.entries)
        for (final territoryId in entry.value) territoryId: entry.key,
    };
  }
}
