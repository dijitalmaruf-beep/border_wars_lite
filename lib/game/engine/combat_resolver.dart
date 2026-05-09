import 'dart:math';

import '../models/attack_result.dart';
import '../models/territory.dart';

class CombatResolver {
  const CombatResolver();

  double calculateWinChance(Territory source, Territory target) {
    final attackerPower = max(0, source.armyCount - 1);
    final defenderPower = target.armyCount * 1.15;
    final totalPower = attackerPower + defenderPower;
    if (attackerPower <= 0 || totalPower <= 0) {
      return 0;
    }
    return attackerPower / totalPower;
  }

  int calculateMovedArmiesOnWin(Territory source) {
    final attackerPower = max(0, source.armyCount - 1);
    if (attackerPower <= 0) {
      return 0;
    }
    return min(source.armyCount - 1, max(1, attackerPower ~/ 2));
  }

  AttackResult resolve({
    required Territory source,
    required Territory target,
    required String attackerId,
    Random? random,
    double? rollOverride,
  }) {
    final winChance = calculateWinChance(source, target);
    final roll = rollOverride ?? (random ?? Random()).nextDouble();
    final attackerPower = max(0, source.armyCount - 1);
    final didWin = roll < winChance;

    if (didWin) {
      final movedArmies = calculateMovedArmiesOnWin(source);
      return AttackResult(
        sourceId: source.id,
        targetId: target.id,
        attackerId: attackerId,
        defenderId: target.ownerId,
        didWin: true,
        winChance: winChance,
        attackerLosses: 0,
        defenderLosses: target.armyCount,
        movedArmies: movedArmies,
        message:
            '${source.name} conquered ${target.name}. Moved $movedArmies in.',
      );
    }

    final rawAttackerLosses = max(1, (attackerPower * 0.4).ceil());
    final attackerLosses = min(source.armyCount - 1, rawAttackerLosses);
    final rawDefenderLosses = max(0, (target.armyCount * 0.2).ceil());
    final defenderLosses = min(target.armyCount, rawDefenderLosses);

    return AttackResult(
      sourceId: source.id,
      targetId: target.id,
      attackerId: attackerId,
      defenderId: target.ownerId,
      didWin: false,
      winChance: winChance,
      attackerLosses: attackerLosses,
      defenderLosses: defenderLosses,
      movedArmies: 0,
      message: '${source.name} failed to take ${target.name}.',
    );
  }
}
