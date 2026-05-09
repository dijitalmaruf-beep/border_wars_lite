import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/local/local_save_repository.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import 'game_screen.dart';
import 'online_setup_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalSaveRepository _localSaveRepository = const LocalSaveRepository();

  bool _isContinuing = false;
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshSavedGameIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        showGlobe: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 34, 26, 28),
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 26),
                      const _HomeEmblem(),
                      const SizedBox(height: 24),
                      const _GameLogo(),
                      const SizedBox(height: 18),
                      const Text(
                        'Conquer the world.\nOutthink your enemies.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 17,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),
                      PremiumButton(
                        label: 'NEW GAME',
                        icon: Icons.sports_martial_arts,
                        onPressed: _startNewGame,
                      ),
                      const SizedBox(height: 14),
                      PremiumButton(
                        label: 'ONLINE GAME',
                        icon: Icons.cloud,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OnlineSetupScreen(),
                            ),
                          );
                        },
                        tone: PremiumButtonTone.teal,
                        height: 56,
                      ),
                      const SizedBox(height: 14),
                      PremiumButton(
                        label: _isContinuing ? 'LOADING SAVE' : 'CONTINUE GAME',
                        icon: _hasSavedGame
                            ? Icons.history
                            : Icons.history_toggle_off,
                        onPressed: _isContinuing ? null : _continueGame,
                        tone: PremiumButtonTone.dark,
                        height: 56,
                      ),
                      const SizedBox(height: 14),
                      PremiumButton(
                        label: 'SETTINGS',
                        icon: Icons.settings,
                        onPressed: _openSettings,
                        tone: PremiumButtonTone.dark,
                        height: 56,
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

  Future<void> _refreshSavedGameIndicator() async {
    final hasSavedGame = await _localSaveRepository.hasSavedGame();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSavedGame = hasSavedGame;
    });
  }

  Future<void> _startNewGame() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SetupScreen()));
    if (mounted) {
      await _refreshSavedGameIndicator();
    }
  }

  Future<void> _continueGame() async {
    setState(() {
      _isContinuing = true;
    });

    final savedState = await _localSaveRepository.loadGameState();

    if (!mounted) {
      return;
    }

    setState(() {
      _isContinuing = false;
    });

    if (savedState == null) {
      await _refreshSavedGameIndicator();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved local game yet. Start a new game first.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(initialState: savedState),
      ),
    );
    if (mounted) {
      await _refreshSavedGameIndicator();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (mounted) {
      await _refreshSavedGameIndicator();
    }
  }
}

class _HomeEmblem extends StatelessWidget {
  const _HomeEmblem();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: <Color>[Color(0xFF3A3222), Color(0xFF111820)],
            ),
            border: Border.all(color: const Color(0xFFC99C51), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.premiumGold.withValues(alpha: 0.24),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        const Icon(Icons.public, size: 78, color: Color(0xFFD6C3A0)),
        const Positioned(
          top: 12,
          child: Icon(Icons.star, size: 36, color: Color(0xFFEBC46B)),
        ),
      ],
    );
  }
}

class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Border Wars Lite',
      child: Column(
        children: <Widget>[
          Text(
            'BORDER',
            textAlign: TextAlign.center,
            style: _logoTextStyle(56),
          ),
          Text('WARS', textAlign: TextAlign.center, style: _logoTextStyle(60)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                width: 70,
                child: Divider(color: Color(0xFFD19B4A)),
              ),
              const SizedBox(width: 16),
              Text(
                'LITE',
                style: _logoTextStyle(
                  25,
                ).copyWith(color: const Color(0xFFFFD78B), letterSpacing: 7),
              ),
              const SizedBox(width: 16),
              const SizedBox(
                width: 70,
                child: Divider(color: Color(0xFFD19B4A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _logoTextStyle(double size) {
    return TextStyle(
      color: AppColors.premiumText,
      fontSize: size,
      height: 0.86,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.2,
      shadows: const <Shadow>[
        Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 4)),
        Shadow(color: Color(0xFFB7B7B7), blurRadius: 1, offset: Offset(0, 1)),
      ],
    );
  }
}
