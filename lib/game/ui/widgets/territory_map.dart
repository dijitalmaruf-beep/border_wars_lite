import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import 'world_conquest_map.dart';

class TerritoryMap extends StatelessWidget {
  const TerritoryMap({
    required this.state,
    required this.validTargetIds,
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
  final Set<String> validTargetIds;
  final ValueChanged<String> onTerritoryTap;

  @override
  Widget build(BuildContext context) {
    return WorldConquestMap(
      state: state,
      validTargetIds: validTargetIds,
      onTerritoryTap: onTerritoryTap,
    );
  }
}
