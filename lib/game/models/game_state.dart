import 'player.dart';
import 'territory.dart';

const Object _gameStateSentinel = Object();

enum GamePhase { reinforce, attack, end }

class GameState {
  GameState({
    required this.id,
    required List<Player> players,
    required List<Territory> territories,
    required this.currentPlayerIndex,
    required this.phase,
    required this.remainingReinforcements,
    required this.turnNumber,
    required this.turnStartedAtMillis,
    this.transferUsedThisTurn = false,
    this.selectedSourceId,
    this.selectedTargetId,
    this.statusMessage = '',
    this.winnerId,
  }) : players = List<Player>.unmodifiable(players),
       territories = List<Territory>.unmodifiable(territories);

  final String id;
  final List<Player> players;
  final List<Territory> territories;
  final int currentPlayerIndex;
  final GamePhase phase;
  final int remainingReinforcements;
  final int turnNumber;
  final int turnStartedAtMillis;
  final bool transferUsedThisTurn;
  final String? selectedSourceId;
  final String? selectedTargetId;
  final String statusMessage;
  final String? winnerId;

  Player get currentPlayer => players[currentPlayerIndex];

  Player? playerById(String? playerId) {
    if (playerId == null) {
      return null;
    }
    for (final player in players) {
      if (player.id == playerId) {
        return player;
      }
    }
    return null;
  }

  Territory territoryById(String territoryId) {
    return territories.firstWhere((territory) => territory.id == territoryId);
  }

  Territory? territoryByIdOrNull(String? territoryId) {
    if (territoryId == null) {
      return null;
    }
    for (final territory in territories) {
      if (territory.id == territoryId) {
        return territory;
      }
    }
    return null;
  }

  int ownedTerritoryCount(String playerId) {
    return territories
        .where((territory) => territory.ownerId == playerId)
        .length;
  }

  List<Territory> territoriesOwnedBy(String playerId) {
    return territories
        .where((territory) => territory.ownerId == playerId)
        .toList(growable: false);
  }

  GameState copyWith({
    String? id,
    List<Player>? players,
    List<Territory>? territories,
    int? currentPlayerIndex,
    GamePhase? phase,
    int? remainingReinforcements,
    int? turnNumber,
    int? turnStartedAtMillis,
    bool? transferUsedThisTurn,
    Object? selectedSourceId = _gameStateSentinel,
    Object? selectedTargetId = _gameStateSentinel,
    String? statusMessage,
    Object? winnerId = _gameStateSentinel,
  }) {
    return GameState(
      id: id ?? this.id,
      players: players ?? this.players,
      territories: territories ?? this.territories,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      remainingReinforcements:
          remainingReinforcements ?? this.remainingReinforcements,
      turnNumber: turnNumber ?? this.turnNumber,
      turnStartedAtMillis: turnStartedAtMillis ?? this.turnStartedAtMillis,
      transferUsedThisTurn: transferUsedThisTurn ?? this.transferUsedThisTurn,
      selectedSourceId: identical(selectedSourceId, _gameStateSentinel)
          ? this.selectedSourceId
          : selectedSourceId as String?,
      selectedTargetId: identical(selectedTargetId, _gameStateSentinel)
          ? this.selectedTargetId
          : selectedTargetId as String?,
      statusMessage: statusMessage ?? this.statusMessage,
      winnerId: identical(winnerId, _gameStateSentinel)
          ? this.winnerId
          : winnerId as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'players': players.map((player) => player.toMap()).toList(),
      'territories': territories.map((territory) => territory.toMap()).toList(),
      'currentPlayerIndex': currentPlayerIndex,
      'phase': phase.name,
      'remainingReinforcements': remainingReinforcements,
      'turnNumber': turnNumber,
      'turnStartedAtMillis': turnStartedAtMillis,
      'transferUsedThisTurn': transferUsedThisTurn,
      'selectedSourceId': selectedSourceId,
      'selectedTargetId': selectedTargetId,
      'statusMessage': statusMessage,
      'winnerId': winnerId,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      id: map['id'] as String,
      players: (map['players'] as List<dynamic>)
          .map(
            (player) => Player.fromMap(
              Map<String, dynamic>.from(player as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      territories: (map['territories'] as List<dynamic>)
          .map(
            (territory) => Territory.fromMap(
              Map<String, dynamic>.from(territory as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      currentPlayerIndex: map['currentPlayerIndex'] as int,
      phase: GamePhase.values.firstWhere(
        (phase) => phase.name == (map['phase'] as String),
      ),
      remainingReinforcements: map['remainingReinforcements'] as int,
      turnNumber: map['turnNumber'] as int,
      turnStartedAtMillis:
          map['turnStartedAtMillis'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      transferUsedThisTurn: map['transferUsedThisTurn'] as bool? ?? false,
      selectedSourceId: map['selectedSourceId'] as String?,
      selectedTargetId: map['selectedTargetId'] as String?,
      statusMessage: map['statusMessage'] as String? ?? '',
      winnerId: map['winnerId'] as String?,
    );
  }
}
