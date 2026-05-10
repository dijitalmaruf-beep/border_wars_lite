import 'package:chroma_conquest/core/constants/app_colors.dart';
import 'package:chroma_conquest/core/constants/game_constants.dart';
import 'package:chroma_conquest/game/engine/game_engine.dart';
import 'package:chroma_conquest/game/engine/map_generator.dart';
import 'package:chroma_conquest/game/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = MapGenerator();
  const engine = GameEngine();

  GameState newState() {
    return generator.createInitialState(
      humanName: 'Alex',
      humanColorValue: AppColors.humanBlueValue,
      seed: 7,
    );
  }

  GameState transferState({
    String sourceId = 'western_us',
    String targetId = 'central_us',
    String? targetOwnerId = GameConstants.humanPlayerId,
    int sourceArmies = 6,
    int targetArmies = 2,
    bool transferUsedThisTurn = false,
  }) {
    final state = newState().copyWith(
      phase: GamePhase.attack,
      remainingReinforcements: 0,
      transferUsedThisTurn: transferUsedThisTurn,
      selectedSourceId: sourceId,
      selectedTargetId: targetId,
    );

    return state.copyWith(
      territories: state.territories.map((territory) {
        if (territory.id == sourceId) {
          return territory.copyWith(
            ownerId: GameConstants.humanPlayerId,
            armyCount: sourceArmies,
          );
        }
        if (territory.id == targetId) {
          return territory.copyWith(
            ownerId: targetOwnerId,
            armyCount: targetArmies,
          );
        }
        return territory;
      }).toList(),
    );
  }

  test('assigns starting and neutral territories for a new game', () {
    final state = newState();

    expect(state.players, hasLength(4));
    expect(state.territories, hasLength(GameConstants.totalTerritories));

    for (final player in state.players) {
      final owned = state.territoriesOwnedBy(player.id);
      expect(owned, hasLength(GameConstants.startingTerritoriesPerPlayer));
      expect(
        owned.map((territory) => territory.armyCount),
        everyElement(GameConstants.startingArmies),
      );
    }

    final neutralTerritories = state.territories
        .where((territory) => territory.ownerId == null)
        .toList();
    expect(
      neutralTerritories,
      hasLength(
        GameConstants.totalTerritories -
            state.players.length * GameConstants.startingTerritoriesPerPlayer,
      ),
    );
    expect(
      neutralTerritories.map((territory) => territory.armyCount),
      everyElement(GameConstants.neutralArmies),
    );
  });

  test(
    'validates attacks by ownership, armies, neighbor, and target owner',
    () {
      final state = transferState(targetOwnerId: null);

      expect(
        engine.canAttack(state, sourceId: 'western_us', targetId: 'central_us'),
        isTrue,
      );
      expect(
        engine.canAttack(state, sourceId: 'western_us', targetId: 'greenland'),
        isFalse,
      );
      expect(
        engine.canAttack(state, sourceId: 'central_us', targetId: 'western_us'),
        isFalse,
      );

      final weakSourceState = state.copyWith(
        territories: state.territories.map((territory) {
          if (territory.id == 'western_us') {
            return territory.copyWith(armyCount: 1);
          }
          return territory;
        }).toList(),
      );

      expect(
        engine.canAttack(
          weakSourceState,
          sourceId: 'western_us',
          targetId: 'central_us',
        ),
        isFalse,
      );
    },
  );

  test('does not select non-neighbor attack targets', () {
    final state = transferState(targetOwnerId: null).copyWith(
      selectedTargetId: null,
      territories: transferState(targetOwnerId: null).territories.map((
        territory,
      ) {
        if (territory.id == 'middle_east') {
          return territory.copyWith(ownerId: null);
        }
        return territory;
      }).toList(),
    );

    final nextState = engine.selectTerritory(state, 'middle_east');

    expect(nextState.selectedSourceId, 'western_us');
    expect(nextState.selectedTargetId, isNull);
    expect(
      nextState.statusMessage,
      'Sadece komşu düşman bölgelerine saldırabilirsin.',
    );
  });

  test('selects only valid neighboring attack targets', () {
    final state = transferState(
      targetOwnerId: null,
    ).copyWith(selectedTargetId: null);

    final nextState = engine.selectTerritory(state, 'central_us');

    expect(nextState.selectedSourceId, 'western_us');
    expect(nextState.selectedTargetId, 'central_us');
    expect(nextState.statusMessage, 'Central US hedef seçildi. Saldırı hazır.');
    expect(engine.movedArmiesOnWinForSelection(nextState), 2);
  });

  test('valid adjacent owned transfer succeeds', () {
    final state = transferState();

    expect(engine.canTransfer(state, 'western_us', 'central_us'), isTrue);

    final nextState = engine.transferArmies(
      state,
      'western_us',
      'central_us',
      3,
    );

    expect(nextState.territoryById('western_us').armyCount, 3);
    expect(nextState.territoryById('central_us').armyCount, 5);
    expect(nextState.transferUsedThisTurn, isTrue);
    expect(nextState.statusMessage, 'Central US bölgesine 3 asker taşındı.');
  });

  test('non-neighbor transfer fails', () {
    final state = transferState(targetId: 'western_europe');

    expect(engine.canTransfer(state, 'western_us', 'western_europe'), isFalse);

    final nextState = engine.transferArmies(
      state,
      'western_us',
      'western_europe',
      2,
    );

    expect(nextState.territoryById('western_us').armyCount, 6);
    expect(nextState.territoryById('western_europe').armyCount, 2);
    expect(nextState.transferUsedThisTurn, isFalse);
  });

  test('enemy target transfer fails', () {
    final state = transferState(targetOwnerId: 'atlas_bot');

    expect(engine.canTransfer(state, 'western_us', 'central_us'), isFalse);

    final nextState = engine.transferArmies(
      state,
      'western_us',
      'central_us',
      2,
    );

    expect(nextState.territoryById('western_us').armyCount, 6);
    expect(nextState.territoryById('central_us').armyCount, 2);
    expect(nextState.transferUsedThisTurn, isFalse);
  });

  test('neutral target transfer fails', () {
    final state = transferState(targetOwnerId: null);

    expect(engine.canTransfer(state, 'western_us', 'central_us'), isFalse);

    final nextState = engine.transferArmies(
      state,
      'western_us',
      'central_us',
      2,
    );

    expect(nextState.territoryById('western_us').armyCount, 6);
    expect(nextState.territoryById('central_us').armyCount, 2);
    expect(nextState.transferUsedThisTurn, isFalse);
  });

  test('source cannot go below one army after transfer', () {
    final state = transferState(sourceArmies: 3);

    final nextState = engine.transferArmies(
      state,
      'western_us',
      'central_us',
      3,
    );

    expect(nextState.territoryById('western_us').armyCount, 3);
    expect(nextState.territoryById('central_us').armyCount, 2);
    expect(nextState.transferUsedThisTurn, isFalse);
  });

  test('transferUsedThisTurn prevents second transfer', () {
    final state = transferState();
    final firstTransfer = engine.transferArmies(
      state,
      'western_us',
      'central_us',
      1,
    );

    final secondTransfer = engine.transferArmies(
      firstTransfer,
      'western_us',
      'central_us',
      1,
    );

    expect(secondTransfer.territoryById('western_us').armyCount, 5);
    expect(secondTransfer.territoryById('central_us').armyCount, 3);
    expect(secondTransfer.transferUsedThisTurn, isTrue);
    expect(secondTransfer.statusMessage, 'Bu tur transfer hakkı kullanıldı.');
  });

  test('transferUsedThisTurn resets on next turn', () {
    final state = transferState(transferUsedThisTurn: true);

    final nextState = engine.endTurn(state);

    expect(nextState.transferUsedThisTurn, isFalse);
    expect(nextState.currentPlayer.id, 'atlas_bot');
  });

  test('new turn clears selections and starts in reinforce phase', () {
    final state = newState().copyWith(
      currentPlayerIndex: 0,
      phase: GamePhase.attack,
      transferUsedThisTurn: true,
      selectedSourceId: 'western_us',
      selectedTargetId: 'central_us',
      territories: newState().territories.map((territory) {
        if (territory.id == 'western_us') {
          return territory.copyWith(ownerId: GameConstants.humanPlayerId);
        }
        if (territory.id == 'eastern_canada') {
          return territory.copyWith(ownerId: 'atlas_bot');
        }
        return territory.copyWith(ownerId: null);
      }).toList(),
    );

    final botTurn = engine.endTurn(state);
    final humanTurn = engine.endTurn(
      botTurn.copyWith(
        phase: GamePhase.attack,
        transferUsedThisTurn: true,
        selectedSourceId: 'eastern_canada',
        selectedTargetId: 'western_us',
      ),
    );

    expect(humanTurn.currentPlayer.id, GameConstants.humanPlayerId);
    expect(humanTurn.phase, GamePhase.reinforce);
    expect(humanTurn.selectedSourceId, isNull);
    expect(humanTurn.selectedTargetId, isNull);
    expect(humanTurn.transferUsedThisTurn, isFalse);
    expect(humanTurn.statusMessage, 'Takviye yapmak için bir bölge seç.');
  });

  test('quick match detects victory at forty percent territory control', () {
    final state = newState().copyWith(matchMode: MatchMode.quick);
    final requiredTerritories = state.matchMode.requiredTerritories(
      state.territories.length,
    );
    final conqueredState = state.copyWith(
      territories: state.territories.asMap().entries.map((entry) {
        return entry.value.copyWith(
          ownerId: entry.key < requiredTerritories
              ? GameConstants.humanPlayerId
              : null,
        );
      }).toList(),
    );

    expect(engine.findWinner(conqueredState), GameConstants.humanPlayerId);
  });

  test(
    'standard match detects victory at seventy percent territory control',
    () {
      final state = newState().copyWith(matchMode: MatchMode.standard);
      final requiredTerritories =
          (state.territories.length * GameConstants.victoryTerritoryRatio)
              .ceil();
      final conqueredState = state.copyWith(
        territories: state.territories.asMap().entries.map((entry) {
          return entry.value.copyWith(
            ownerId: entry.key < requiredTerritories
                ? GameConstants.humanPlayerId
                : null,
          );
        }).toList(),
      );

      expect(engine.findWinner(conqueredState), GameConstants.humanPlayerId);
    },
  );

  test('conquest detects victory when only one non-neutral player remains', () {
    final state = newState().copyWith(matchMode: MatchMode.conquest);
    final soloState = state.copyWith(
      territories: state.territories.map((territory) {
        return territory.copyWith(
          ownerId: territory.ownerId == GameConstants.humanPlayerId
              ? GameConstants.humanPlayerId
              : null,
        );
      }).toList(),
    );

    expect(engine.findWinner(soloState), GameConstants.humanPlayerId);
  });

  test('conquest detects victory when one player controls every territory', () {
    final state = newState().copyWith(
      matchMode: MatchMode.conquest,
      territories: newState().territories.map((territory) {
        return territory.copyWith(ownerId: GameConstants.humanPlayerId);
      }).toList(),
    );

    expect(engine.findWinner(state), GameConstants.humanPlayerId);
  });

  test('match mode is stored in GameState serialization', () {
    final state = newState().copyWith(matchMode: MatchMode.quick);
    final restored = GameState.fromMap(state.toMap());

    expect(restored.matchMode, MatchMode.quick);
  });

  test('event log keeps the last ten events', () {
    var state = newState();
    for (var index = 0; index < 12; index += 1) {
      state = state.addEvent('event $index');
    }

    expect(state.eventLog, hasLength(10));
    expect(state.eventLog.first, 'event 2');
    expect(state.eventLog.last, 'event 11');
  });
}
