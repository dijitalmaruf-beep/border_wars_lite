class GameSettings {
  const GameSettings({
    this.autoSaveLocalGame = true,
    this.confirmEndTurn = false,
  });

  final bool autoSaveLocalGame;
  final bool confirmEndTurn;

  GameSettings copyWith({bool? autoSaveLocalGame, bool? confirmEndTurn}) {
    return GameSettings(
      autoSaveLocalGame: autoSaveLocalGame ?? this.autoSaveLocalGame,
      confirmEndTurn: confirmEndTurn ?? this.confirmEndTurn,
    );
  }
}
