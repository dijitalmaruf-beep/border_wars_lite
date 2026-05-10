import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../engine/map_generator.dart';
import '../../models/game_state.dart';
import '../widgets/commander_banner_picker.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: GameConstants.defaultHumanName,
  );
  int _selectedColorValue = AppColors.humanBlueValue;
  int _selectedBotCount = GameConstants.defaultBotPlayers;
  MatchMode _selectedMatchMode = MatchMode.standard;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.premiumText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SetupHeader(),
                      const SizedBox(height: 28),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('KOMUTAN ADI'),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: AppColors.premiumText,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Komutan adını gir...',
                                hintStyle: const TextStyle(
                                  color: AppColors.premiumMutedText,
                                ),
                                prefixIcon: const Icon(Icons.person),
                                prefixIconColor: const Color(0xFFD8D1C8),
                                filled: true,
                                fillColor: const Color(0xAA06121D),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF748395),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.premiumCyan,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('MAÇ MODU'),
                            const SizedBox(height: 14),
                            _MatchModeSelector(
                              selectedMode: _selectedMatchMode,
                              onChanged: (mode) {
                                setState(() {
                                  _selectedMatchMode = mode;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('SANCAĞINI SEÇ'),
                            const SizedBox(height: 16),
                            CommanderBannerPicker(
                              colorValues: AppColors.humanColorValues,
                              selectedColorValue: _selectedColorValue,
                              onSelected: (colorValue) {
                                setState(() {
                                  _selectedColorValue = colorValue;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('BOT KOMUTANLAR'),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                _StepperButton(
                                  icon: Icons.remove,
                                  onPressed:
                                      _selectedBotCount >
                                          GameConstants.minBotPlayers
                                      ? () => _changeBotCount(-1)
                                      : null,
                                ),
                                Expanded(
                                  child: Column(
                                    children: <Widget>[
                                      Text(
                                        '$_selectedBotCount',
                                        style: const TextStyle(
                                          color: AppColors.premiumText,
                                          fontSize: 34,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _selectedBotCount == 1
                                            ? 'bot rakip'
                                            : 'bot rakip',
                                        style: const TextStyle(
                                          color: AppColors.premiumMutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _StepperButton(
                                  icon: Icons.add,
                                  onPressed:
                                      _selectedBotCount <
                                          GameConstants.maxBotPlayers
                                      ? () => _changeBotCount(1)
                                      : null,
                                ),
                              ],
                            ),
                            Slider(
                              value: _selectedBotCount.toDouble(),
                              min: GameConstants.minBotPlayers.toDouble(),
                              max: GameConstants.maxBotPlayers.toDouble(),
                              divisions:
                                  GameConstants.maxBotPlayers -
                                  GameConstants.minBotPlayers,
                              activeColor: AppColors.premiumCyan,
                              inactiveColor: AppColors.premiumBorder,
                              onChanged: (value) {
                                setState(() {
                                  _selectedBotCount = value.round();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const PremiumPanel(
                        borderColor: Color(0xFFB9915A),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.workspace_premium,
                              color: Color(0xFFEFC66F),
                              size: 42,
                            ),
                            SizedBox(width: 18),
                            Expanded(
                              child: Text(
                                'Her komutan 3 bölge ve 6 askerle başlar.',
                                style: TextStyle(
                                  color: AppColors.premiumText,
                                  height: 1.35,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      PremiumButton(
                        label: 'OYUNU BAŞLAT',
                        icon: Icons.flag,
                        onPressed: _startGame,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    final initialState = const MapGenerator().createInitialState(
      humanName: _nameController.text,
      humanColorValue: _selectedColorValue,
      botCount: _selectedBotCount,
      matchMode: _selectedMatchMode,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(initialState: initialState),
      ),
    );
  }

  void _changeBotCount(int delta) {
    setState(() {
      _selectedBotCount = (_selectedBotCount + delta)
          .clamp(GameConstants.minBotPlayers, GameConstants.maxBotPlayers)
          .toInt();
    });
  }
}

class _MatchModeSelector extends StatelessWidget {
  const _MatchModeSelector({
    required this.selectedMode,
    required this.onChanged,
  });

  final MatchMode selectedMode;
  final ValueChanged<MatchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MatchMode.values
          .map((mode) {
            final isSelected = mode == selectedMode;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode == MatchMode.conquest ? 0 : 8,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isSelected
                            ? const <Color>[
                                Color(0xFF087BFF),
                                Color(0xFF003B99),
                              ]
                            : const <Color>[
                                Color(0xFF12202D),
                                Color(0xFF07111A),
                              ],
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.premiumCyan
                            : AppColors.premiumBorder,
                        width: isSelected ? 1.4 : 1,
                      ),
                      boxShadow: <BoxShadow>[
                        if (isSelected)
                          BoxShadow(
                            color: AppColors.premiumBlue.withValues(
                              alpha: 0.32,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _modeTitle(mode),
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.premiumText,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _modeSubtitle(mode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFFD66D)
                                : AppColors.premiumMutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  String _modeTitle(MatchMode mode) {
    switch (mode) {
      case MatchMode.quick:
        return 'HIZLI';
      case MatchMode.standard:
        return 'STANDART';
      case MatchMode.conquest:
        return 'FETİH';
    }
  }

  String _modeSubtitle(MatchMode mode) {
    switch (mode) {
      case MatchMode.quick:
        return '%40';
      case MatchMode.standard:
        return '%70';
      case MatchMode.conquest:
        return 'Tam kontrol';
    }
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        Text(
          'KOMUTAN KURULUMU',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.premiumText,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(width: 82, child: Divider(color: Color(0xFF566473))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.star, color: Color(0xFFE7C371), size: 16),
            ),
            SizedBox(width: 82, child: Divider(color: Color(0xFF566473))),
          ],
        ),
        SizedBox(height: 14),
        Text(
          'Kimliğini seç ve imparatorluğuna liderlik et.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.premiumMutedText, fontSize: 16),
        ),
      ],
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.premiumText,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xAA06121D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onPressed == null
                ? AppColors.premiumBorder.withValues(alpha: 0.32)
                : AppColors.premiumCyan.withValues(alpha: 0.70),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed == null
              ? AppColors.premiumMutedText.withValues(alpha: 0.55)
              : AppColors.premiumText,
        ),
      ),
    );
  }
}
