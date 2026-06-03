import 'dart:math';

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
          statusMessage: 'Takviye için kendi bölgelerinden birini seç.',
        );
      }
      return addReinforcementsToTerritory(state, territoryId);
    }

    if (territory.ownerId == state.currentPlayer.id) {
      return state.copyWith(
        selectedSourceId: territoryId,
        selectedTargetId: null,
        statusMessage: '${territory.name} seçildi.',
      );
    }

    if (state.selectedSourceId == null) {
      return state.copyWith(statusMessage: 'Önce saldırı kaynağını seç.');
    }

    final source = state.territoryById(state.selectedSourceId!);
    if (!source.isNeighbor(territoryId)) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Sadece komşu düşman bölgelerine saldırabilirsin.',
      );
    }

    if (source.armyCount <= 1) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Saldırmak için kaynak bölgede 1 askerden fazla olmalı.',
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
        statusMessage: 'Sadece komşu düşman bölgelerine saldırabilirsin.',
      );
    }

    return state.copyWith(
      selectedTargetId: territoryId,
      statusMessage: '${territory.name} hedef seçildi. Saldırı hazır.',
    );
  }

  GameState addReinforcementsToTerritory(GameState state, String territoryId) {
    if (state.remainingReinforcements <= 0) {
      return state.copyWith(phase: GamePhase.attack);
    }

    final territory = state.territoryById(territoryId);
    if (territory.ownerId != state.currentPlayer.id) {
      return state.copyWith(statusMessage: 'Kendi bölgeni seçmelisin.');
    }

    final updatedTerritory = territory.copyWith(
      armyCount: territory.armyCount + state.remainingReinforcements,
    );

    final nextState = state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedTerritory.id: updatedTerritory,
      }),
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      selectedSourceId: territoryId,
      selectedTargetId: null,
      statusMessage: '${territory.name} takviye aldı.',
    );
    return nextState.addEvent(
      '${state.currentPlayer.name} reinforced ${territory.name} +${state.remainingReinforcements}.',
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
      return state.copyWith(statusMessage: 'Bu tur transfer hakkı kullanıldı.');
    }
    if (!canTransfer(state, sourceId, targetId)) {
      return state.copyWith(statusMessage: 'Geçersiz transfer.');
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    final maxTransfer = source.armyCount - 1;
    if (amount < 1 || amount > maxTransfer) {
      return state.copyWith(
        statusMessage: 'Kaynak bölgede en az 1 asker kalmalı.',
      );
    }

    final updatedSource = source.copyWith(armyCount: source.armyCount - amount);
    final updatedTarget = target.copyWith(armyCount: target.armyCount + amount);

    final nextState = state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedSource.id: updatedSource,
        updatedTarget.id: updatedTarget,
      }),
      transferUsedThisTurn: true,
      selectedSourceId: updatedSource.id,
      selectedTargetId: updatedTarget.id,
      statusMessage: '${updatedTarget.name} bölgesine $amount asker taşındı.',
    );
    return nextState.addEvent(
      '${state.currentPlayer.name} transferred $amount armies to ${target.name}.',
    );
  }

  double winChanceForSelection(GameState state) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    if (source == null || target == null) {
      return 0;
    }
    return _difficultyAdjustedWinChance(state, source, target);
  }

  int movedArmiesOnWinForSelection(GameState state) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    if (source == null || target == null) {
      return 0;
    }
    if (!canAttack(state, sourceId: source.id, targetId: target.id)) {
      return 0;
    }
    return combatResolver.calculateMovedArmiesOnWin(source);
  }

  int maxMovedArmiesOnWinForSelection(GameState state) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    if (source == null || target == null) {
      return 0;
    }
    if (!canAttack(state, sourceId: source.id, targetId: target.id)) {
      return 0;
    }
    return combatResolver.maxMovedArmiesOnWin(source);
  }

  AttackResult? resolveSelectedAttack(GameState state, {Random? random}) {
    final sourceId = state.selectedSourceId;
    final targetId = state.selectedTargetId;
    if (sourceId == null || targetId == null) {
      return null;
    }
    return resolveAttackResult(
      state,
      sourceId: sourceId,
      targetId: targetId,
      random: random,
    );
  }

  AttackResult? resolveAttackResult(
    GameState state, {
    required String sourceId,
    required String targetId,
    Random? random,
  }) {
    if (!canAttack(state, sourceId: sourceId, targetId: targetId)) {
      return null;
    }

    final source = state.territoryById(sourceId);
    final target = state.territoryById(targetId);
    return combatResolver.resolve(
      source: source,
      target: target,
      attackerId: state.currentPlayer.id,
      random: random,
      winChanceOverride: _difficultyAdjustedWinChance(state, source, target),
    );
  }

  double _difficultyAdjustedWinChance(
    GameState state,
    Territory source,
    Territory target,
  ) {
    final baseChance = combatResolver.calculateWinChance(source, target);
    final attacker = state.currentPlayer;
    final defender = state.playerById(target.ownerId);
    if (attacker.isBot) {
      return (baseChance * state.difficulty.botAttackWinChanceMultiplier)
          .clamp(0.02, 0.96)
          .toDouble();
    }
    if (defender != null && defender.isBot) {
      return (baseChance * state.difficulty.humanVsBotAttackWinChanceMultiplier)
          .clamp(0.02, 0.96)
          .toDouble();
    }
    return baseChance.clamp(0.0, 1.0).toDouble();
  }

  GameState attackSelected(GameState state, {Random? random}) {
    final sourceId = state.selectedSourceId;
    final targetId = state.selectedTargetId;
    if (sourceId == null || targetId == null) {
      return state.copyWith(statusMessage: 'Saldırı hedefi seçilmedi.');
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
    final result = resolveAttackResult(
      state,
      sourceId: sourceId,
      targetId: targetId,
      random: random,
    );
    if (result == null) {
      return state.copyWith(statusMessage: 'Geçersiz saldırı.');
    }
    return applyAttackResult(state, result);
  }

  GameState applyAttackResult(GameState state, AttackResult result) {
    final source = state.territoryById(result.sourceId);
    final target = state.territoryById(result.targetId);

    late final Territory updatedSource;
    late final Territory updatedTarget;

    if (result.didWin) {
      final movedArmies = result.movedArmies
          .clamp(1, source.armyCount - 1)
          .toInt();
      updatedSource = source.copyWith(
        armyCount: max(1, source.armyCount - movedArmies),
      );
      updatedTarget = target.copyWith(
        ownerId: result.attackerId,
        armyCount: movedArmies,
      );
    } else {
      updatedSource = source.copyWith(
        armyCount: max(1, source.armyCount - result.attackerLosses),
      );
      updatedTarget = target.copyWith(
        armyCount: max(0, target.armyCount - result.defenderLosses),
      );
    }

    var nextState = state.copyWith(
      territories: _replaceTerritories(state.territories, <String, Territory>{
        updatedSource.id: updatedSource,
        updatedTarget.id: updatedTarget,
      }),
      selectedSourceId: updatedSource.id,
      selectedTargetId: null,
      statusMessage: result.didWin
          ? '${target.name} fethedildi. ${updatedTarget.armyCount} asker bölgeye geçti.'
          : result.message,
    );

    nextState = nextState.addEvent(
      result.didWin
          ? '${state.currentPlayer.name} captured ${target.name}.'
          : '${state.currentPlayer.name} failed attack on ${target.name}.',
    );

    final winnerId = findWinner(nextState);
    if (winnerId != null) {
      final winnerName = nextState.playerById(winnerId)?.name ?? winnerId;
      final winningState = nextState.copyWith(
        phase: GamePhase.end,
        winnerId: winnerId,
        statusMessage: '${nextState.playerById(winnerId)?.name} kazandı!',
      );
      return winningState.addEvent('$winnerName won the match.');
    }
    return nextState;
  }

  GameState endTurn(GameState state) {
    final winnerId = findWinner(state);
    if (winnerId != null) {
      final winnerName = state.playerById(winnerId)?.name ?? winnerId;
      final winningState = state.copyWith(
        phase: GamePhase.end,
        winnerId: winnerId,
        selectedSourceId: null,
        selectedTargetId: null,
      );
      return winningState.addEvent('$winnerName won the match.');
    }

    final nextPlayerIndex = _nextActivePlayerIndex(state);
    final nextPlayer = state.players[nextPlayerIndex];
    final reinforcements = reinforcementCalculator.calculateForPlayer(
      state,
      nextPlayer.id,
    );

    final nextState = state.copyWith(
      currentPlayerIndex: nextPlayerIndex,
      phase: GamePhase.reinforce,
      remainingReinforcements: reinforcements,
      transferUsedThisTurn: false,
      selectedSourceId: null,
      selectedTargetId: null,
      turnNumber: state.turnNumber + 1,
      turnStartedAtMillis: DateTime.now().millisecondsSinceEpoch,
      statusMessage: nextPlayer.isBot
          ? '${nextPlayer.name} ${state.turnNumber + 1}. tura başladı.'
          : 'Takviye yapmak için bir bölge seç.',
    );
    return nextState.addEvent(
      'Turn ${nextState.turnNumber}: ${nextPlayer.name} turn started.',
    );
  }

  GameState runBotTurn(GameState state, {Random? random}) {
    if (!state.currentPlayer.isBot || state.winnerId != null) {
      return state;
    }

    var nextState = state.addEvent(
      '${state.currentPlayer.name} is reinforcing.',
    );
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
      attackNumber < state.difficulty.maxBotAttacks;
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
    final totalTerritories = state.territories.length;

    switch (state.matchMode) {
      case MatchMode.quick:
      case MatchMode.standard:
        final requiredTerritories = state.matchMode.requiredTerritories(
          totalTerritories,
        );
        for (final player in state.players) {
          if (state.ownedTerritoryCount(player.id) >= requiredTerritories) {
            return player.id;
          }
        }
        return null;
      case MatchMode.conquest:
        for (final player in state.players) {
          if (state.ownedTerritoryCount(player.id) == totalTerritories) {
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
