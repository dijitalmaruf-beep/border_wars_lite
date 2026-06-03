import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../models/game_state.dart';

class ContinentBonus {
  const ContinentBonus({required this.continent, required this.value});

  final String continent;
  final int value;
}

class ReinforcementBreakdown {
  const ReinforcementBreakdown({
    required this.base,
    required this.continentBonus,
    required this.controlledContinents,
    this.difficultyBonus = 0,
  });

  final int base;
  final int continentBonus;
  final int difficultyBonus;
  final List<ContinentBonus> controlledContinents;

  int get total => base + continentBonus + difficultyBonus;
}

class ReinforcementCalculator {
  const ReinforcementCalculator();

  static const Map<String, int> continentBonusValues = <String, int>{
    'North America': 5,
    'South America': 3,
    'Europe': 5,
    'Africa': 4,
    'Asia': 7,
    'Oceania': 2,
  };
  static const Map<String, int> strategicTerritoryBonusValues = <String, int>{
    'anatolia': 3,
  };
  static const Map<String, String> strategicTerritoryBonusNames =
      <String, String>{'anatolia': 'Anatolia'};

  int calculateForOwnedTerritories(int ownedTerritoryCount) {
    return max(GameConstants.minReinforcements, ownedTerritoryCount ~/ 3);
  }

  int calculateForPlayer(GameState state, String playerId) {
    return breakdownForPlayer(state, playerId).total;
  }

  ReinforcementBreakdown breakdownForPlayer(GameState state, String playerId) {
    final base = calculateForOwnedTerritories(
      state.ownedTerritoryCount(playerId),
    );
    final controlledContinents = controlledContinentBonuses(state, playerId);
    final continentBonus = controlledContinents.fold<int>(
      0,
      (total, bonus) => total + bonus.value,
    );
    final rawTotal = base + continentBonus;
    final player = state.playerById(playerId);
    final difficultyBonus = player != null && player.isBot
        ? max(
            0,
            (rawTotal * (state.difficulty.botReinforcementMultiplier - 1))
                .round(),
          )
        : 0;

    return ReinforcementBreakdown(
      base: base,
      continentBonus: continentBonus,
      difficultyBonus: difficultyBonus,
      controlledContinents: controlledContinents,
    );
  }

  List<ContinentBonus> controlledContinentBonuses(
    GameState state,
    String playerId,
  ) {
    final territoriesByContinent = <String, int>{};
    final ownedByContinent = <String, int>{};

    for (final territory in state.territories) {
      territoriesByContinent.update(
        territory.continent,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (territory.ownerId == playerId) {
        ownedByContinent.update(
          territory.continent,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final bonuses = <ContinentBonus>[];
    for (final entry in continentBonusValues.entries) {
      final totalInContinent = territoriesByContinent[entry.key] ?? 0;
      if (totalInContinent > 0 &&
          ownedByContinent[entry.key] == totalInContinent) {
        bonuses.add(ContinentBonus(continent: entry.key, value: entry.value));
      }
    }
    for (final entry in strategicTerritoryBonusValues.entries) {
      final territory = state.territoryByIdOrNull(entry.key);
      if (territory?.ownerId == playerId) {
        bonuses.add(
          ContinentBonus(
            continent: strategicTerritoryBonusNames[entry.key] ?? entry.key,
            value: entry.value,
          ),
        );
      }
    }
    return List<ContinentBonus>.unmodifiable(bonuses);
  }
}
