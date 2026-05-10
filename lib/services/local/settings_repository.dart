import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_language.dart';
import 'game_settings.dart';

class SettingsRepository {
  const SettingsRepository();

  static const _autoSaveKey = 'chroma_conquest.settings.auto_save';
  static const _confirmEndTurnKey = 'chroma_conquest.settings.confirm_end_turn';
  static const _languageCodeKey = 'chroma_conquest.settings.language_code';

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
