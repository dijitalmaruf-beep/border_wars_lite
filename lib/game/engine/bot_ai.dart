import '../models/bot_personality.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/territory.dart';
import 'combat_resolver.dart';
import 'reinforcement_calculator.dart';

class BotAttackPlan {
  const BotAttackPlan({
    required this.sourceId,
    required this.targetId,
    required this.winChance,
    required this.score,
  });

  final String sourceId;
  final String targetId;
  final double winChance;
  final double score;
}

class BotAI {
  const BotAI({this.combatResolver = const CombatResolver()});

  final CombatResolver combatResolver;

  Territory? chooseReinforcementTerritory(GameState state, String botPlayerId) {
    final owned = state.territoriesOwnedBy(botPlayerId);
    if (owned.isEmpty) {
      return null;
    }

    final borderTerritories = owned.where(
      (territory) => territory.neighbors.any(
        (neighborId) => state.territoryById(neighborId).ownerId != botPlayerId,
      ),
    );

    final botPlayer = state.playerById(botPlayerId);
    final candidates = borderTerritories.isEmpty ? owned : borderTerritories;
    final sorted = candidates.toList()
      ..sort(
        (left, right) => _reinforcementScore(
          state,
          right,
          botPlayer,
        ).compareTo(_reinforcementScore(state, left, botPlayer)),
      );
    return sorted.first;
  }

  BotAttackPlan? chooseBestAttack(GameState state, Player botPlayer) {
    final personality =
        botPlayer.botPersonality ?? BotPersonality.opportunistic;
    final threshold =
        (personality.attackThreshold +
                state.difficulty.attackThresholdAdjustment)
            .clamp(0.25, 0.90)
            .toDouble();
    final plans =
        findValidAttackPlans(
            state,
            botPlayer,
          ).where((plan) => plan.winChance >= threshold).toList()
          ..sort((left, right) => right.score.compareTo(left.score));

    if (plans.isEmpty) {
      return null;
    }
    return plans.first;
  }

  List<BotAttackPlan> findValidAttackPlans(GameState state, Player botPlayer) {
    final plans = <BotAttackPlan>[];
    for (final source in state.territoriesOwnedBy(botPlayer.id)) {
      if (source.armyCount <= 1) {
        continue;
      }
      for (final neighborId in source.neighbors) {
        final target = state.territoryById(neighborId);
        if (target.ownerId == botPlayer.id) {
          continue;
        }
        final winChance = combatResolver.calculateWinChance(source, target);
        plans.add(
          BotAttackPlan(
            sourceId: source.id,
            targetId: target.id,
            winChance: winChance,
            score: _attackScore(state, botPlayer.id, winChance, source, target),
          ),
        );
      }
    }
    return plans;
  }

  int _enemyPressure(GameState state, Territory territory, String botPlayerId) {
    var pressure = 0;
    for (final neighborId in territory.neighbors) {
      final neighbor = state.territoryById(neighborId);
      if (neighbor.ownerId != botPlayerId) {
        pressure += neighbor.armyCount;
      }
    }
    return pressure;
  }

  double _reinforcementScore(
    GameState state,
    Territory territory,
    Player? botPlayer,
  ) {
    final botPlayerId = botPlayer?.id ?? territory.ownerId;
    if (botPlayerId == null) {
      return 0;
    }

    final attackTargets = territory.neighbors
        .map(state.territoryById)
        .where((neighbor) => neighbor.ownerId != botPlayerId)
        .toList(growable: false);
    final enemyPressure = _enemyPressure(state, territory, botPlayerId);
    final weakestTargetArmies = attackTargets.isEmpty
        ? 0
        : attackTargets
              .map((target) => target.armyCount)
              .reduce((left, right) => left < right ? left : right);
    final projectedSource = territory.copyWith(
      armyCount: territory.armyCount + state.remainingReinforcements,
    );
    final bestProjectedAttack = attackTargets.fold<double>(0, (best, target) {
      final chance = combatResolver.calculateWinChance(projectedSource, target);
      final score = _attackScore(
        state,
        botPlayerId,
        chance,
        projectedSource,
        target,
      );
      return score > best ? score : best;
    });
    final continentProgress = _continentProgress(
      state,
      botPlayerId,
      territory.continent,
    );
    final strategicBonus =
        ReinforcementCalculator.strategicTerritoryBonusValues
            .containsKey(territory.id)
        ? 0.65
        : 0.0;
    final difficultyFocus = switch (state.difficulty) {
      GameDifficulty.easy => 0.72,
      GameDifficulty.normal => 1.00,
      GameDifficulty.hard => 1.42,
    };

    return enemyPressure * 0.12 +
        (attackTargets.length * 0.14 + (6 - weakestTargetArmies).clamp(0, 6) * 0.05) *
            difficultyFocus +
        bestProjectedAttack * (0.42 + difficultyFocus * 0.22) +
        continentProgress * (0.26 + difficultyFocus * 0.18) +
        strategicBonus * difficultyFocus +
        territory.armyCount * 0.02;
  }

  double _attackScore(
    GameState state,
    String botPlayerId,
    double winChance,
    Territory source,
    Territory target,
  ) {
    final neutralBonus = target.ownerId == null ? 0.04 : 0.16;
    final expansionValue = target.neighbors.length / 24;
    final sourceSafety = source.armyCount / 120;
    final targetArmyValue = target.ownerId == null
        ? target.armyCount * 0.012
        : target.armyCount * 0.026;
    final completionBonus = _continentCaptureBonus(state, botPlayerId, target);
    final denialBonus = _opponentContinentDenialBonus(state, target);
    final eliminationBonus =
        target.ownerId != null && state.ownedTerritoryCount(target.ownerId!) == 1
        ? 0.62
        : 0.0;
    final strategicBonus =
        ReinforcementCalculator.strategicTerritoryBonusValues
            .containsKey(target.id)
        ? 0.40
        : 0.0;
    final frontierBonus = _frontierValue(state, botPlayerId, target);
    final sourceRiskPenalty = _sourceRiskPenalty(state, botPlayerId, source);
    final difficultyFocus = switch (state.difficulty) {
      GameDifficulty.easy => 0.72,
      GameDifficulty.normal => 1.00,
      GameDifficulty.hard => 1.38,
    };

    return winChance * (1.0 + difficultyFocus * 0.08) +
        neutralBonus +
        expansionValue +
        sourceSafety +
        targetArmyValue +
        (completionBonus + denialBonus + eliminationBonus + strategicBonus) *
            difficultyFocus +
        frontierBonus * (0.85 + difficultyFocus * 0.18) -
        sourceRiskPenalty;
  }

  double _continentProgress(
    GameState state,
    String playerId,
    String continent,
  ) {
    var total = 0;
    var owned = 0;
    for (final territory in state.territories) {
      if (territory.continent != continent) {
        continue;
      }
      total += 1;
      if (territory.ownerId == playerId) {
        owned += 1;
      }
    }
    if (total == 0) {
      return 0;
    }
    return owned / total;
  }

  double _continentCaptureBonus(
    GameState state,
    String playerId,
    Territory target,
  ) {
    final continentValue =
        ReinforcementCalculator.continentBonusValues[target.continent] ?? 0;
    if (continentValue == 0) {
      return 0;
    }

    var missing = 0;
    for (final territory in state.territories) {
      if (territory.continent == target.continent &&
          territory.ownerId != playerId) {
        missing += 1;
      }
    }
    if (missing == 1) {
      return 0.34 + continentValue * 0.055;
    }
    if (missing == 2) {
      return 0.16 + continentValue * 0.030;
    }
    return _continentProgress(state, playerId, target.continent) * 0.08;
  }

  double _opponentContinentDenialBonus(GameState state, Territory target) {
    final targetOwnerId = target.ownerId;
    if (targetOwnerId == null) {
      return 0;
    }
    final continentValue =
        ReinforcementCalculator.continentBonusValues[target.continent] ?? 0;
    if (continentValue == 0) {
      return 0;
    }
    final opponentControlsContinent = state.territories
        .where((territory) => territory.continent == target.continent)
        .every((territory) => territory.ownerId == targetOwnerId);
    return opponentControlsContinent ? 0.22 + continentValue * 0.030 : 0;
  }

  double _frontierValue(
    GameState state,
    String botPlayerId,
    Territory target,
  ) {
    var friendlyNeighbors = 0;
    var enemyNeighbors = 0;
    for (final neighborId in target.neighbors) {
      final neighbor = state.territoryById(neighborId);
      if (neighbor.ownerId == botPlayerId) {
        friendlyNeighbors += 1;
      } else {
        enemyNeighbors += 1;
      }
    }
    return friendlyNeighbors * 0.045 + enemyNeighbors * 0.020;
  }

  double _sourceRiskPenalty(
    GameState state,
    String botPlayerId,
    Territory source,
  ) {
    final hostilePressure = source.neighbors
        .map(state.territoryById)
        .where((neighbor) => neighbor.ownerId != botPlayerId)
        .fold<int>(0, (total, neighbor) => total + neighbor.armyCount);
    if (hostilePressure <= source.armyCount) {
      return 0;
    }
    return ((hostilePressure - source.armyCount) / 30).clamp(0.0, 0.18);
  }
}
