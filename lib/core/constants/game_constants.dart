class GameConstants {
  const GameConstants._();

  static const humanPlayerId = 'human';
  static const neutralOwnerId = null;
  static const defaultHumanName = 'Commander';

  static const defaultBotPlayers = 3;
  static const minBotPlayers = 1;
  static const maxBotPlayers = 9;
  static const maxOnlineHumanPlayers = 5;
  static const turnDurationSeconds = 90;
  static const totalBotPlayers = defaultBotPlayers;
  static const totalTerritories = 47;
  static const startingTerritoriesPerPlayer = 3;
  static const startingArmies = 6;
  static const neutralArmies = 2;
  static const minReinforcements = 3;
  static const maxBotAttacksPerTurn = 2;
  static const victoryTerritoryRatio = 0.70;
}
