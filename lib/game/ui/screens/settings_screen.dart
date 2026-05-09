import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/local/game_settings.dart';
import '../../../services/local/local_save_repository.dart';
import '../../../services/local/settings_repository.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settingsRepository = const SettingsRepository();
  final LocalSaveRepository _localSaveRepository = const LocalSaveRepository();

  GameSettings _settings = const GameSettings();
  bool _isLoading = true;
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.premiumText,
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'SETTINGS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.premiumText,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tune local play options for this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.premiumMutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.premiumCyan,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              PremiumPanel(
                                child: Column(
                                  children: <Widget>[
                                    _SettingsSwitch(
                                      title: 'Auto-save local games',
                                      subtitle:
                                          'Continue Game will resume your latest local match.',
                                      value: _settings.autoSaveLocalGame,
                                      onChanged: (value) => _updateSettings(
                                        _settings.copyWith(
                                          autoSaveLocalGame: value,
                                        ),
                                      ),
                                    ),
                                    const _SettingsDivider(),
                                    _SettingsSwitch(
                                      title: 'Confirm end turn',
                                      subtitle:
                                          'Ask before ending your turn in local matches.',
                                      value: _settings.confirmEndTurn,
                                      onChanged: (value) => _updateSettings(
                                        _settings.copyWith(
                                          confirmEndTurn: value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              PremiumPanel(
                                borderColor: _hasSavedGame
                                    ? AppColors.premiumGold.withValues(
                                        alpha: 0.62,
                                      )
                                    : AppColors.premiumBorder,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Icon(
                                          _hasSavedGame
                                              ? Icons.save
                                              : Icons.save_outlined,
                                          color: _hasSavedGame
                                              ? AppColors.premiumGold
                                              : AppColors.premiumMutedText,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _hasSavedGame
                                                ? 'A local save is available.'
                                                : 'No local save yet.',
                                            style: const TextStyle(
                                              color: AppColors.premiumText,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    PremiumButton(
                                      label: 'CLEAR SAVED GAME',
                                      icon: Icons.delete_outline,
                                      onPressed: _hasSavedGame
                                          ? _confirmClearSavedGame
                                          : null,
                                      tone: PremiumButtonTone.red,
                                      height: 50,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.loadSettings();
    final hasSavedGame = await _localSaveRepository.hasSavedGame();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _hasSavedGame = hasSavedGame;
      _isLoading = false;
    });
  }

  Future<void> _updateSettings(GameSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await _settingsRepository.saveSettings(settings);
  }

  Future<void> _confirmClearSavedGame() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101923),
        title: const Text(
          'Clear saved game?',
          style: TextStyle(color: AppColors.premiumText),
        ),
        content: const Text(
          'This removes the local Continue Game save on this device.',
          style: TextStyle(color: AppColors.premiumMutedText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !mounted) {
      return;
    }

    await _localSaveRepository.clearSavedGame();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSavedGame = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved game cleared.')));
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.premiumCyan,
      activeTrackColor: AppColors.premiumCyan.withValues(alpha: 0.35),
      inactiveThumbColor: AppColors.premiumMutedText,
      inactiveTrackColor: AppColors.premiumBorder.withValues(alpha: 0.35),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.premiumText,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.premiumMutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.premiumBorder.withValues(alpha: 0.50),
      height: 18,
    );
  }
}
