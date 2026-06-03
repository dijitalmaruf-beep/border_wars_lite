import '../models/bot_personality.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/territory.dart';
import 'combat_resolver.dart';

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

    final candidates = borderTerritories.isEmpty ? owned : borderTerritories;
    final sorted = candidates.toList()
      ..sort(
        (left, right) => _enemyPressure(
          state,
          right,
          botPlayerId,
        ).compareTo(_enemyPressure(state, left, botPlayerId)),
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
        final winChance =
            (combatResolver.calculateWinChance(source, target) *
                    state.difficulty.botAttackWinChanceMultiplier)
                .clamp(0.02, 0.96)
                .toDouble();
        plans.add(
          BotAttackPlan(
            sourceId: source.id,
            targetId: target.id,
            winChance: winChance,
            score: _attackScore(winChance, source, target),
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

  double _attackScore(double winChance, Territory source, Territory target) {
    final neutralBonus = target.ownerId == null ? 0.08 : 0;
    final expansionValue = target.neighbors.length / 20;
    final sourceSafety = source.armyCount / 100;
    return winChance + neutralBonus + expansionValue + sourceSafety;
  }
}
