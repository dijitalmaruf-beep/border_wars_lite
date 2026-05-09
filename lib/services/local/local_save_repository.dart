import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../game/models/game_state.dart';

class LocalSaveRepository {
  const LocalSaveRepository();

  static const _saveKey = 'border_wars_lite.local_game_state';

  Future<void> saveGameState(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(state.toMap()));
  }

  Future<GameState?> loadGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_saveKey);
    if (savedState == null || savedState.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(savedState) as Map<String, dynamic>;
      return GameState.fromMap(decoded);
    } catch (_) {
      await clearSavedGame();
      return null;
    }
  }

  Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }
}
