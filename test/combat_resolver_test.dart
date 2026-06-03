import 'package:chroma_conquest/game/engine/combat_resolver.dart';
import 'package:chroma_conquest/game/models/territory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = CombatResolver();
  final source = Territory(
    id: 'source',
    name: 'Source',
    x: 0,
    y: 0,
    ownerId: 'attacker',
    armyCount: 10,
    neighbors: const ['target'],
    continent: 'Test',
  );
  final target = Territory(
    id: 'target',
    name: 'Target',
    x: 1,
    y: 1,
    ownerId: 'defender',
    armyCount: 4,
    neighbors: const ['source'],
    continent: 'Test',
  );

  test('calculates win chance from attacker and defender power', () {
    final chance = resolver.calculateWinChance(source, target);

    expect(chance, closeTo(9 / (9 + 4 * 1.15), 0.0001));
  });

  test('overwhelming attacks are guaranteed to conquer', () {
    final overwhelmingSource = source.copyWith(armyCount: 40);
    final reinforcedTarget = target.copyWith(armyCount: 8);

    final result = resolver.resolve(
      source: overwhelmingSource,
      target: reinforcedTarget,
      attackerId: 'attacker',
      rollOverride: 0.999,
    );

    expect(
      resolver.calculateWinChance(overwhelmingSource, reinforcedTarget),
      1,
    );
    expect(result.didWin, isTrue);
  });

  test('calculates moved armies on conquest before attack resolves', () {
    expect(resolver.calculateMovedArmiesOnWin(source), 4);
  });

  test('keeps combat results within army bounds on win', () {
    final result = resolver.resolve(
      source: source,
      target: target,
      attackerId: 'attacker',
      rollOverride: 0,
    );

    expect(result.didWin, isTrue);
    expect(result.movedArmies, greaterThanOrEqualTo(1));
    expect(result.movedArmies, lessThanOrEqualTo(source.armyCount - 1));
    expect(result.defenderLosses, target.armyCount);
    expect(result.message, 'Target fethedildi. 4 asker ilerledi.');
  });

  test('keeps combat results within army bounds on loss', () {
    final result = resolver.resolve(
      source: source,
      target: target,
      attackerId: 'attacker',
      rollOverride: 1,
    );

    expect(result.didWin, isFalse);
    expect(result.attackerLosses, greaterThanOrEqualTo(1));
    expect(result.attackerLosses, lessThanOrEqualTo(source.armyCount - 1));
    expect(result.defenderLosses, greaterThanOrEqualTo(0));
    expect(result.defenderLosses, lessThanOrEqualTo(target.armyCount));
  });
}
