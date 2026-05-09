import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

class SettingsRepository {
  const SettingsRepository();

  static const _autoSaveKey = 'border_wars_lite.settings.auto_save';
  static const _confirmEndTurnKey =
      'border_wars_lite.settings.confirm_end_turn';

  Future<GameSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return GameSettings(
      autoSaveLocalGame: prefs.getBool(_autoSaveKey) ?? true,
      confirmEndTurn: prefs.getBool(_confirmEndTurnKey) ?? false,
    );
  }

  Future<void> saveSettings(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveKey, settings.autoSaveLocalGame);
    await prefs.setBool(_confirmEndTurnKey, settings.confirmEndTurn);
  }
}
