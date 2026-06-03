import 'player.dart';
import 'territory.dart';

const Object _gameStateSentinel = Object();

enum GamePhase { reinforce, attack, end }

enum MatchMode { quick, standard, conquest }

enum GameDifficulty { easy, normal, hard }

extension GameDifficultyInfo on GameDifficulty {
  double get attackThresholdAdjustment {
    switch (this) {
      case GameDifficulty.easy:
        return 0.06;
      case GameDifficulty.normal:
        return -0.06;
      case GameDifficulty.hard:
        return -0.20;
    }
  }

  int get maxBotAttacks {
    switch (this) {
      case GameDifficulty.easy:
        return 2;
      case GameDifficulty.normal:
        return 3;
      case GameDifficulty.hard:
        return 5;
    }
  }
}

extension MatchModeInfo on MatchMode {
  double? get territoryRatio {
    switch (this) {
      case MatchMode.quick:
        return 0.40;
      case MatchMode.standard:
        return 0.70;
      case MatchMode.conquest:
        return null;
    }
  }

  int requiredTerritories(int totalTerritories) {
    final ratio = territoryRatio;
    if (ratio == null) {
      return totalTerritories;
    }
    return (totalTerritories * ratio).ceil();
  }
}

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
    this.matchMode = MatchMode.standard,
    this.difficulty = GameDifficulty.normal,
    this.transferUsedThisTurn = false,
    this.selectedSourceId,
    this.selectedTargetId,
    this.statusMessage = '',
    this.winnerId,
    List<String> eventLog = const <String>[],
  }) : players = List<Player>.unmodifiable(players),
       territories = List<Territory>.unmodifiable(territories),
       eventLog = List<String>.unmodifiable(eventLog);

  final String id;
  final List<Player> players;
  final List<Territory> territories;
  final int currentPlayerIndex;
  final GamePhase phase;
  final int remainingReinforcements;
  final int turnNumber;
  final int turnStartedAtMillis;
  final MatchMode matchMode;
  final GameDifficulty difficulty;
  final bool transferUsedThisTurn;
  final String? selectedSourceId;
  final String? selectedTargetId;
  final String statusMessage;
  final String? winnerId;
  final List<String> eventLog;

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
    MatchMode? matchMode,
    GameDifficulty? difficulty,
    bool? transferUsedThisTurn,
    Object? selectedSourceId = _gameStateSentinel,
    Object? selectedTargetId = _gameStateSentinel,
    String? statusMessage,
    Object? winnerId = _gameStateSentinel,
    List<String>? eventLog,
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
      matchMode: matchMode ?? this.matchMode,
      difficulty: difficulty ?? this.difficulty,
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
      eventLog: eventLog ?? this.eventLog,
    );
  }

  GameState addEvent(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return this;
    }
    final nextLog = <String>[...eventLog, trimmed];
    final compactLog = nextLog.length <= 10
        ? nextLog
        : nextLog.sublist(nextLog.length - 10);
    return copyWith(eventLog: compactLog);
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
      'matchMode': matchMode.name,
      'difficulty': difficulty.name,
      'transferUsedThisTurn': transferUsedThisTurn,
      'selectedSourceId': selectedSourceId,
      'selectedTargetId': selectedTargetId,
      'statusMessage': statusMessage,
      'winnerId': winnerId,
      'eventLog': eventLog,
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
      matchMode: MatchMode.values.firstWhere(
        (mode) => mode.name == (map['matchMode'] as String?),
        orElse: () => MatchMode.standard,
      ),
      difficulty: GameDifficulty.values.firstWhere(
        (difficulty) => difficulty.name == (map['difficulty'] as String?),
        orElse: () => GameDifficulty.normal,
      ),
      transferUsedThisTurn: map['transferUsedThisTurn'] as bool? ?? false,
      selectedSourceId: map['selectedSourceId'] as String?,
      selectedTargetId: map['selectedTargetId'] as String?,
      statusMessage: map['statusMessage'] as String? ?? '',
      winnerId: map['winnerId'] as String?,
      eventLog: (map['eventLog'] as List<dynamic>? ?? const <dynamic>[])
          .map((event) => event.toString())
          .toList(),
    );
  }
}
