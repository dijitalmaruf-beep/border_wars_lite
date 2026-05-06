class AttackResult {
  const AttackResult({
    required this.sourceId,
    required this.targetId,
    required this.attackerId,
    required this.defenderId,
    required this.didWin,
    required this.winChance,
    required this.attackerLosses,
    required this.defenderLosses,
    required this.movedArmies,
    required this.message,
  });

  final String sourceId;
  final String targetId;
  final String attackerId;
  final String? defenderId;
  final bool didWin;
  final double winChance;
  final int attackerLosses;
  final int defenderLosses;
  final int movedArmies;
  final String message;
}
