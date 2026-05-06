import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../models/game_state.dart';

class ReinforcementCalculator {
  const ReinforcementCalculator();

  int calculateForOwnedTerritories(int ownedTerritoryCount) {
    return max(
      GameConstants.minReinforcements,
      ownedTerritoryCount ~/ 3,
    );
  }

  int calculateForPlayer(GameState state, String playerId) {
    return calculateForOwnedTerritories(state.ownedTerritoryCount(playerId));
  }
}
