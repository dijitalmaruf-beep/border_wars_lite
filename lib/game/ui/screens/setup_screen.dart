import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../engine/map_generator.dart';
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
                    const Spacer(),
                    const _SetupHeader(),
                    const SizedBox(height: 28),
                    PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _PanelLabel('COMMANDER NAME'),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: AppColors.premiumText),
                            decoration: InputDecoration(
                              hintText: 'Enter commander name...',
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
                          const _PanelLabel('CHOOSE YOUR COLOR'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: AppColors.humanColorValues.map((colorValue) {
                              final isSelected = colorValue == _selectedColorValue;
                              return _ColorOrb(
                                colorValue: colorValue,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedColorValue = colorValue;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 44),
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
                              'Each commander starts with 3 territories and 6 armies.',
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
                    const Spacer(flex: 2),
                    PremiumButton(
                      label: 'START GAME',
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
    );
  }

  void _startGame() {
    final initialState = const MapGenerator().createInitialState(
      humanName: _nameController.text,
      humanColorValue: _selectedColorValue,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(initialState: initialState),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        Text(
          'COMMANDER SETUP',
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
          'Choose your identity and lead your empire.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.premiumMutedText,
            fontSize: 16,
          ),
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

class _ColorOrb extends StatelessWidget {
  const _ColorOrb({
    required this.colorValue,
    required this.isSelected,
    required this.onTap,
  });

  final int colorValue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSelected ? 'Selected' : 'Select color',
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Color(colorValue).withValues(alpha: 0.98),
                Color(colorValue).withValues(alpha: 0.64),
              ],
            ),
            border: Border.all(
              color: isSelected ? Colors.white : Color(colorValue),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: <BoxShadow>[
              if (isSelected)
                BoxShadow(
                  color: Color(colorValue).withValues(alpha: 0.65),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 30)
              : null,
        ),
      ),
    );
  }
}
