enum BotPersonality {
  aggressive,
  opportunistic,
  defensive;

  double get attackThreshold {
    switch (this) {
      case BotPersonality.aggressive:
        return 0.45;
      case BotPersonality.opportunistic:
        return 0.60;
      case BotPersonality.defensive:
        return 0.75;
    }
  }

  String get label {
    switch (this) {
      case BotPersonality.aggressive:
        return 'Aggressive';
      case BotPersonality.opportunistic:
        return 'Opportunistic';
      case BotPersonality.defensive:
        return 'Defensive';
    }
  }
}
