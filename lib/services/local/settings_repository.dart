import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_language.dart';
import 'game_settings.dart';

class SettingsRepository {
  const SettingsRepository();

  static const _autoSaveKey = 'border_wars_lite.settings.auto_save';
  static const _confirmEndTurnKey =
      'border_wars_lite.settings.confirm_end_turn';
  static const _languageCodeKey = 'border_wars_lite.settings.language_code';

  Future<GameSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return GameSettings(
      autoSaveLocalGame: prefs.getBool(_autoSaveKey) ?? true,
      confirmEndTurn: prefs.getBool(_confirmEndTurnKey) ?? false,
      languageCode: AppLanguageController.normalize(
        prefs.getString(_languageCodeKey),
      ),
    );
  }

  Future<void> saveSettings(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveKey, settings.autoSaveLocalGame);
    await prefs.setBool(_confirmEndTurnKey, settings.confirmEndTurn);
    await prefs.setString(
      _languageCodeKey,
      AppLanguageController.normalize(settings.languageCode),
    );
  }
}
