import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../models/attack_result.dart';
import '../models/game_state.dart';
import '../models/territory.dart';
import 'bot_ai.dart';
import 'combat_resolver.dart';
import 'reinforcement_calculator.dart';

class GameEngine {
  const GameEngine({
    this.combatResolver = const CombatResolver(),
    this.reinforcementCalculator = const ReinforcementCalculator(),
    this.botAI = const BotAI(),
  });

  final CombatResolver combatResolver;
  final ReinforcementCalculator reinforcementCalculator;
  final BotAI botAI;

  GameState selectTerritory(GameState state, String territoryId) {
    if (state.currentPlayer.isBot || state.winnerId != null) {
      return state;
    }

    final territory = state.territoryById(territoryId);
    if (state.phase == GamePhase.reinforce) {
      if (territory.ownerId != state.currentPlayer.id) {
        return state.copyWith(
          statusMessage: 'Reinforcements need friendly ground.',
        );
      }
      return addReinforcementsToTerritory(state, territoryId);
    }

    if (territory.ownerId == state.currentPlayer.id) {
      return state.copyWith(
        selectedSourceId: territoryId,
        selectedTargetId: null,
        statusMessage: '${territory.name} selected.',
      );
    }

    if (state.selectedSourceId == null) {
      return state.copyWith(statusMessage: 'Select a source territory first.');
    }

    final source = state.territoryById(state.selectedSourceId!);
    if (!source.isNeighbor(territoryId)) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Only neighboring enemy territories can be attacked.',
      );
    }

    if (source.armyCount <= 1) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Source needs more than 1 army to attack.',
      );
    }

    final canAttackTarget = canAttack(
      state,
      sourceId: state.selectedSourceId!,
      targetId: territoryId,
    );

    if (!canAttackTarget) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Only neighboring enemy territories can be attacked.',
      );
    }

    return state.copyWith(
      selectedTargetId: territoryId,
      statusMessage: 'Attack route ready.',
    );
  }

  GameState addReinforcementsToTerritory(GameState state, String territoryId) {
    if (state.remainingReinforcements <= 0) {
      return state.copyWith(phase: GamePhase.attack);
    }

    final territory = state.territoryById(territoryId);
    if (territory.ownerId != state.currentPlayer.id) {
      return state.copyWith(statusMessage: 'Choose a territory you own.');
    }

    final updatedTerritory = territory.copyWith(
      armyCount: territory.armyCount + state.remainingReinforcements,
    );

    return state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedTerritory.id: updatedTerritory,
      }),
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      selectedSourceId: territoryId,
      selectedTargetId: null,
      statusMessage:
          '${state.currentPlayer.name} reinforced ${territory.name}.',
    );
  }

  bool canAttack(
    GameState state, {
    required String sourceId,
    required String targetId,
  }) {
    if (state.winnerId != null || state.phase != GamePhase.attack) {
      return false;
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    final currentPlayerId = state.currentPlayer.id;

    return source.ownerId == currentPlayerId &&
        source.armyCount > 1 &&
        source.isNeighbor(target.id) &&
        target.ownerId != currentPlayerId;
  }

  bool canTransfer(GameState state, String sourceId, String targetId) {
    if (state.winnerId != null ||
        state.phase != GamePhase.attack ||
        state.transferUsedThisTurn) {
      return false;
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    final currentPlayerId = state.currentPlayer.id;

    return source.id != target.id &&
        source.ownerId == currentPlayerId &&
        target.ownerId == currentPlayerId &&
        source.armyCount > 1 &&
        source.isNeighbor(target.id);
  }

  GameState transferArmies(
    GameState state,
    String sourceId,
    String targetId,
    int amount,
  ) {
    if (state.transferUsedThisTurn) {
      return state.copyWith(statusMessage: 'Transfer already used this turn.');
    }
    if (!canTransfer(state, sourceId, targetId)) {
      return state.copyWith(statusMessage: 'Invalid transfer.');
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    final maxTransfer = source.armyCount - 1;
    if (amount < 1 || amount > maxTransfer) {
      return state.copyWith(
        statusMessage: 'Transfer amount must leave 1 army behind.',
      );
    }

    final updatedSource = source.copyWith(armyCount: source.armyCount - amount);
    final updatedTarget = target.copyWith(armyCount: target.armyCount + amount);

    return state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedSource.id: updatedSource,
        updatedTarget.id: updatedTarget,
      }),
      transferUsedThisTurn: true,
      selectedSourceId: updatedSource.id,
      selectedTargetId: updatedTarget.id,
      statusMessage: 'Transferred $amount armies to ${updatedTarget.name}.',
    );
  }

  double winChanceForSelection(GameState state) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    if (source == null || target == null) {
      return 0;
    }
    return combatResolver.calculateWinChance(source, target);
  }

  GameState attackSelected(GameState state, {Random? random}) {
    final sourceId = state.selectedSourceId;
    final targetId = state.selectedTargetId;
    if (sourceId == null || targetId == null) {
      return state.copyWith(statusMessage: 'No attack selected.');
    }
    return attack(
      state,
      sourceId: sourceId,
      targetId: targetId,
      random: random,
    );
  }

  GameState attack(
    GameState state, {
    required String sourceId,
    required String targetId,
    Random? random,
  }) {
    if (!canAttack(state, sourceId: sourceId, targetId: targetId)) {
      return state.copyWith(statusMessage: 'Invalid attack.');
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    final result = combatResolver.resolve(
      source: source,
      target: target,
      attackerId: state.currentPlayer.id,
      random: random,
    );
    return applyAttackResult(state, result);
  }

  GameState applyAttackResult(GameState state, AttackResult result) {
    final source = state.territoryById(result.sourceId);
    final target = state.territoryById(result.targetId);

    late final Territory updatedSource;
    late final Territory updatedTarget;

    if (result.didWin) {
      updatedSource = source.copyWith(
        armyCount: max(1, source.armyCount - result.movedArmies),
      );
      updatedTarget = target.copyWith(
        ownerId: result.attackerId,
        armyCount: result.movedArmies,
      );
    } else {
      updatedSource = source.copyWith(
        armyCount: max(1, source.armyCount - result.attackerLosses),
      );
      updatedTarget = target.copyWith(
        armyCount: max(0, target.armyCount - result.defenderLosses),
      );
    }

    final nextState = state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedSource.id: updatedSource,
        updatedTarget.id: updatedTarget,
      }),
      selectedSourceId: updatedSource.id,
      selectedTargetId: null,
      statusMessage: result.message,
    );

    final winnerId = findWinner(nextState);
    if (winnerId != null) {
      return nextState.copyWith(
        phase: GamePhase.end,
        winnerId: winnerId,
        statusMessage: '${nextState.playerById(winnerId)?.name} wins!',
      );
    }
    return nextState;
  }

  GameState endTurn(GameState state) {
    final winnerId = findWinner(state);
    if (winnerId != null) {
      return state.copyWith(
        phase: GamePhase.end,
        winnerId: winnerId,
        selectedSourceId: null,
        selectedTargetId: null,
      );
    }

    final nextPlayerIndex = _nextActivePlayerIndex(state);
    final nextPlayer = state.players[nextPlayerIndex];
    final reinforcements = reinforcementCalculator.calculateForPlayer(
      state,
      nextPlayer.id,
    );

    return state.copyWith(
      currentPlayerIndex: nextPlayerIndex,
      phase: GamePhase.reinforce,
      remainingReinforcements: reinforcements,
      transferUsedThisTurn: false,
      selectedSourceId: null,
      selectedTargetId: null,
      turnNumber: state.turnNumber + 1,
      turnStartedAtMillis: DateTime.now().millisecondsSinceEpoch,
      statusMessage: nextPlayer.isBot
          ? '${nextPlayer.name} begins turn ${state.turnNumber + 1}.'
          : 'Choose a territory to reinforce.',
    );
  }

  GameState runBotTurn(GameState state, {Random? random}) {
    if (!state.currentPlayer.isBot || state.winnerId != null) {
      return state;
    }

    var nextState = state;
    final bot = nextState.currentPlayer;
    final reinforcementTarget = botAI.chooseReinforcementTerritory(
      nextState,
      bot.id,
    );

    if (reinforcementTarget != null && nextState.remainingReinforcements > 0) {
      nextState = addReinforcementsToTerritory(
        nextState,
        reinforcementTarget.id,
      );
    } else {
      nextState = nextState.copyWith(
        phase: GamePhase.attack,
        remainingReinforcements: 0,
      );
    }

    for (
      var attackNumber = 0;
      attackNumber < GameConstants.maxBotAttacksPerTurn;
      attackNumber += 1
    ) {
      final plan = botAI.chooseBestAttack(nextState, bot);
      if (plan == null) {
        break;
      }

      nextState = attack(
        nextState,
        sourceId: plan.sourceId,
        targetId: plan.targetId,
        random: random,
      );

      if (nextState.winnerId != null) {
        return nextState;
      }
    }

    nextState = _runBotTransfer(nextState);

    return endTurn(nextState.copyWith(phase: GamePhase.end));
  }

  String? findWinner(GameState state) {
    final requiredTerritories =
        (state.territories.length * GameConstants.victoryTerritoryRatio).ceil();

    for (final player in state.players) {
      final ownedCount = state.ownedTerritoryCount(player.id);
      if (ownedCount >= requiredTerritories) {
        return player.id;
      }
    }

    final activePlayers = state.players
        .where((player) => state.ownedTerritoryCount(player.id) > 0)
        .toList(growable: false);
    if (activePlayers.length == 1) {
      return activePlayers.first.id;
    }

    return null;
  }

  int _nextActivePlayerIndex(GameState state) {
    var nextIndex = state.currentPlayerIndex;
    for (var attempt = 0; attempt < state.players.length; attempt += 1) {
      nextIndex = (nextIndex + 1) % state.players.length;
      final player = state.players[nextIndex];
      if (state.ownedTerritoryCount(player.id) > 0) {
        return nextIndex;
      }
    }
    return state.currentPlayerIndex;
  }

  GameState _runBotTransfer(GameState state) {
    if (state.transferUsedThisTurn || state.phase != GamePhase.attack) {
      return state;
    }

    final botPlayerId = state.currentPlayer.id;
    final owned = state.territoriesOwnedBy(botPlayerId);
    final borderIds = <String>{
      for (final territory in owned)
        if (territory.neighbors.any(
          (neighborId) =>
              state.territoryById(neighborId).ownerId != botPlayerId,
        ))
          territory.id,
    };

    final innerSources =
        owned
            .where(
              (territory) =>
                  territory.armyCount > 3 && !borderIds.contains(territory.id),
            )
            .toList()
          ..sort((left, right) => right.armyCount.compareTo(left.armyCount));

    for (final source in innerSources) {
      final targets =
          source.neighbors
              .map(state.territoryById)
              .where(
                (territory) =>
                    territory.ownerId == botPlayerId &&
                    borderIds.contains(territory.id) &&
                    territory.armyCount < source.armyCount,
              )
              .toList()
            ..sort((left, right) => left.armyCount.compareTo(right.armyCount));

      if (targets.isEmpty) {
        continue;
      }

      final amount = min(2, source.armyCount - 1);
      return transferArmies(state, source.id, targets.first.id, amount);
    }

    return state;
  }

  List<Territory> _replaceTerritories(
    List<Territory> territories,
    Map<String, Territory> replacements,
  ) {
    return territories
        .map((territory) => replacements[territory.id] ?? territory)
        .toList(growable: false);
  }
}
