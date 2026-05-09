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

  AttackResult copyWith({
    String? sourceId,
    String? targetId,
    String? attackerId,
    Object? defenderId = _attackResultSentinel,
    bool? didWin,
    double? winChance,
    int? attackerLosses,
    int? defenderLosses,
    int? movedArmies,
    String? message,
  }) {
    return AttackResult(
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      attackerId: attackerId ?? this.attackerId,
      defenderId: identical(defenderId, _attackResultSentinel)
          ? this.defenderId
          : defenderId as String?,
      didWin: didWin ?? this.didWin,
      winChance: winChance ?? this.winChance,
      attackerLosses: attackerLosses ?? this.attackerLosses,
      defenderLosses: defenderLosses ?? this.defenderLosses,
      movedArmies: movedArmies ?? this.movedArmies,
      message: message ?? this.message,
    );
  }
}

const Object _attackResultSentinel = Object();
