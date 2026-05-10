class GameSettings {
  const GameSettings({
    this.autoSaveLocalGame = true,
    this.confirmEndTurn = false,
    this.languageCode = 'tr',
  });

  final bool autoSaveLocalGame;
  final bool confirmEndTurn;
  final String languageCode;

  GameSettings copyWith({
    bool? autoSaveLocalGame,
    bool? confirmEndTurn,
    String? languageCode,
  }) {
    return GameSettings(
      autoSaveLocalGame: autoSaveLocalGame ?? this.autoSaveLocalGame,
      confirmEndTurn: confirmEndTurn ?? this.confirmEndTurn,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
