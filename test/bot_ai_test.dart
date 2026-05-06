import 'package:border_wars_lite/core/constants/app_colors.dart';
import 'package:border_wars_lite/game/engine/bot_ai.dart';
import 'package:border_wars_lite/game/engine/game_engine.dart';
import 'package:border_wars_lite/game/engine/map_generator.dart';
import 'package:border_wars_lite/game/models/game_state.dart';
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
}
