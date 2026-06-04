import 'package:chroma_conquest/core/constants/app_colors.dart';
import 'package:chroma_conquest/game/engine/bot_ai.dart';
import 'package:chroma_conquest/game/engine/game_engine.dart';
import 'package:chroma_conquest/game/engine/map_generator.dart';
import 'package:chroma_conquest/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = MapGenerator();
  const botAI = BotAI();
  const engine = GameEngine();

  test('selects only valid attacks for bot personality threshold', () {
    final state = generator
        .createInitialState(
          humanName: 'Alex',
          humanColorValue: AppColors.humanBlueValue,
        )
        .copyWith(
          currentPlayerIndex: 1,
          phase: GamePhase.attack,
          remainingReinforcements: 0,
        );
    final atlasBot = state.currentPlayer;
    final plan = botAI.chooseBestAttack(state, atlasBot);

    expect(plan, isNotNull);
    expect(
      engine.canAttack(
        state,
        sourceId: plan!.sourceId,
        targetId: plan.targetId,
      ),
      isTrue,
    );
    expect(plan.winChance, greaterThanOrEqualTo(0.45));
  });

  test('places bot reinforcements on owned border territory', () {
    final state = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
    );
    final atlasBot = state.players[1];
    final territory = botAI.chooseReinforcementTerritory(state, atlasBot.id);

    expect(territory, isNotNull);
    expect(territory!.ownerId, atlasBot.id);
    expect(
      territory.neighbors.any(
        (neighborId) => state.territoryById(neighborId).ownerId != atlasBot.id,
      ),
      isTrue,
    );
  });

  test(
    'hard difficulty lets bots take riskier attacks than easy difficulty',
    () {
      final baseState = generator.createInitialState(
        humanName: 'Alex',
        humanColorValue: AppColors.humanBlueValue,
        seed: 7,
      );
      final combatState = baseState.copyWith(
        currentPlayerIndex: 1,
        phase: GamePhase.attack,
        remainingReinforcements: 0,
        territories: baseState.territories.map((territory) {
          if (territory.id == 'western_us') {
            return territory.copyWith(ownerId: 'atlas_bot', armyCount: 3);
          }
          if (territory.id == 'central_us') {
            return territory.copyWith(ownerId: 'human', armyCount: 3);
          }
          return territory.copyWith(ownerId: null);
        }).toList(),
      );
      final atlasBot = combatState.currentPlayer;

      expect(
        botAI.chooseBestAttack(
          combatState.copyWith(difficulty: GameDifficulty.easy),
          atlasBot,
        ),
        isNull,
      );
      expect(
        botAI.chooseBestAttack(
          combatState.copyWith(difficulty: GameDifficulty.hard),
          atlasBot,
        ),
        isNotNull,
      );
    },
  );

  test('hard bot prioritizes completing a continent', () {
    final baseState = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 11,
    );
    final combatState = baseState.copyWith(
      currentPlayerIndex: 1,
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      difficulty: GameDifficulty.hard,
      territories: baseState.territories.map((territory) {
        if (territory.continent == 'South America' && territory.id != 'brazil') {
          final armies = territory.id == 'amazon_basin' ? 5 : 3;
          return territory.copyWith(ownerId: 'atlas_bot', armyCount: armies);
        }
        if (territory.id == 'brazil') {
          return territory.copyWith(ownerId: 'human', armyCount: 1);
        }
        if (territory.id == 'western_us') {
          return territory.copyWith(ownerId: 'atlas_bot', armyCount: 8);
        }
        if (territory.id == 'central_us') {
          return territory.copyWith(ownerId: 'human', armyCount: 1);
        }
        return territory.copyWith(ownerId: null, armyCount: 2);
      }).toList(),
    );

    final plan = botAI.chooseBestAttack(combatState, combatState.currentPlayer);

    expect(plan, isNotNull);
    expect(plan!.targetId, 'brazil');
  });

  test('hard bot reinforces a front that can unlock a continent', () {
    final baseState = generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 13,
    );
    final reinforceState = baseState.copyWith(
      currentPlayerIndex: 1,
      phase: GamePhase.reinforce,
      remainingReinforcements: 3,
      difficulty: GameDifficulty.hard,
      territories: baseState.territories.map((territory) {
        if (territory.continent == 'South America' && territory.id != 'brazil') {
          return territory.copyWith(ownerId: 'atlas_bot', armyCount: 1);
        }
        if (territory.id == 'brazil') {
          return territory.copyWith(ownerId: 'human', armyCount: 2);
        }
        if (territory.id == 'western_us') {
          return territory.copyWith(ownerId: 'atlas_bot', armyCount: 4);
        }
        if (territory.id == 'central_us') {
          return territory.copyWith(ownerId: 'human', armyCount: 2);
        }
        return territory.copyWith(ownerId: null, armyCount: 2);
      }).toList(),
    );

    final target = botAI.chooseReinforcementTerritory(
      reinforceState,
      'atlas_bot',
    );

    expect(target, isNotNull);
    expect(
      target!.id,
      isIn(<String>{'amazon_basin', 'southern_cone', 'northern_south_america'}),
    );
  });
}
