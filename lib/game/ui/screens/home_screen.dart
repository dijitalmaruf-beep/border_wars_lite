import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/local/local_save_repository.dart';
import '../widgets/how_to_play_dialog.dart';
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
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _HomeAmbientDepth()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => showHowToPlayDialog(context),
                              icon: const Icon(Icons.help_outline),
                              color: AppColors.premiumText,
                              tooltip: 'Nasıl oynanır',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _HomeEmblem(),
                          const SizedBox(height: 24),
                          const _GameLogo(),
                          const SizedBox(height: 18),
                          const _HomeTagline(),
                          const SizedBox(height: 34),
                          PremiumButton(
                            label: 'YENİ OYUN',
                            icon: Icons.sports_martial_arts,
                            onPressed: _startNewGame,
                          ),
                          const SizedBox(height: 14),
                          PremiumButton(
                            label: 'ONLINE OYUN',
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
                            label: _isContinuing
                                ? 'KAYIT YÜKLENİYOR'
                                : 'DEVAM ET',
                            icon: _hasSavedGame
                                ? Icons.history
                                : Icons.history_toggle_off,
                            onPressed: _isContinuing ? null : _continueGame,
                            tone: PremiumButtonTone.dark,
                            height: 56,
                          ),
                          const SizedBox(height: 14),
                          PremiumButton(
                            label: 'AYARLAR',
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
          ],
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
          content: Text('Kayıtlı oyun yok. Önce yeni oyun başlat.'),
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

class _HomeAmbientDepth extends StatelessWidget {
  const _HomeAmbientDepth();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: 76,
            left: -100,
            right: -100,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.premiumBlue.withValues(alpha: 0.18),
                    AppColors.premiumCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const <double>[0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            bottom: 92,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.premiumGold.withValues(alpha: 0.18),
                    blurRadius: 42,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTagline extends StatelessWidget {
  const _HomeTagline();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x3A06121D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.premiumBorder.withValues(alpha: 0.38),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.premiumBlue.withValues(alpha: 0.10),
            blurRadius: 18,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Text(
          'Tek Renk. Tüm Dünya.\nSon renk kalana kadar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.premiumMutedText,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HomeEmblem extends StatelessWidget {
  const _HomeEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE6B45F), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.premiumGold.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.premiumCyan.withValues(alpha: 0.12),
            blurRadius: 22,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/branding/app_icon.png', fit: BoxFit.cover),
    );
  }
}

class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chroma Conquest',
      child: Column(
        children: <Widget>[
          Text(
            'CHROMA',
            textAlign: TextAlign.center,
            style: _logoTextStyle(50),
          ),
          Text(
            'CONQUEST',
            textAlign: TextAlign.center,
            style: _logoTextStyle(44),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 170,
            child: Divider(color: Color(0xFFD19B4A), thickness: 1.2),
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
