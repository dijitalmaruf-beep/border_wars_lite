import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../services/firebase/firebase_service.dart';
import '../../../services/firebase/firestore_game_repository.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import 'game_screen.dart';

class OnlineSetupScreen extends StatefulWidget {
  const OnlineSetupScreen({super.key});

  @override
  State<OnlineSetupScreen> createState() => _OnlineSetupScreenState();
}

class _OnlineSetupScreenState extends State<OnlineSetupScreen> {
  final FirestoreGameRepository _repository = FirestoreGameRepository();
  final TextEditingController _nameController = TextEditingController(
    text: GameConstants.defaultHumanName,
  );
  final TextEditingController _codeController = TextEditingController();

  StreamSubscription<OnlineGameSession?>? _waitingSubscription;
  OnlineGameSession? _createdSession;
  int _selectedColorValue = AppColors.humanBlueValue;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _waitingSubscription?.cancel();
    _nameController.dispose();
    _codeController.dispose();
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
                          onPressed: _isBusy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.premiumText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ONLINE WAR ROOM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create a room code or join a commander.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (!FirebaseService.isAvailable) ...<Widget>[
                        PremiumPanel(
                          borderColor: AppColors.premiumRed,
                          child: Text(
                            'Firebase is not configured for this build yet. '
                            'Add the Firebase Android/Web config files, then '
                            'online play will activate automatically.',
                            style: const TextStyle(
                              color: AppColors.premiumText,
                              height: 1.35,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('COMMANDER NAME'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameController,
                              enabled: !_isBusy,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: AppColors.premiumText,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Enter commander name...',
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _PanelLabel('CHOOSE YOUR COLOR'),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: AppColors.humanColorValues.map((
                                colorValue,
                              ) {
                                return _ColorOrb(
                                  colorValue: colorValue,
                                  isSelected: colorValue == _selectedColorValue,
                                  onTap: _isBusy
                                      ? null
                                      : () {
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
                      const SizedBox(height: 16),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _PanelLabel('JOIN ROOM CODE'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              enabled: !_isBusy,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              style: const TextStyle(
                                color: AppColors.premiumText,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: _inputDecoration(
                                hint: 'ABC123',
                                icon: Icons.tag,
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 10),
                            PremiumButton(
                              label: 'JOIN ONLINE GAME',
                              icon: Icons.login,
                              onPressed: _canUseOnline && !_isBusy
                                  ? _joinGame
                                  : null,
                              tone: PremiumButtonTone.teal,
                              height: 52,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumButton(
                        label: _isBusy ? 'CONNECTING...' : 'CREATE ROOM',
                        icon: Icons.add_link,
                        onPressed: _canUseOnline && !_isBusy
                            ? _createGame
                            : null,
                        tone: PremiumButtonTone.blue,
                        height: 58,
                      ),
                      if (_createdSession != null) ...<Widget>[
                        const SizedBox(height: 16),
                        PremiumPanel(
                          borderColor: AppColors.premiumGold,
                          child: Column(
                            children: <Widget>[
                              const Text(
                                'ROOM CODE',
                                style: TextStyle(
                                  color: Color(0xFFFFD66D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                _createdSession!.gameId,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.premiumText,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: _createdSession!.gameId,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Code'),
                              ),
                              const Text(
                                'Waiting for another player to join...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.premiumMutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.premiumRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  bool get _canUseOnline => FirebaseService.isAvailable;

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.premiumMutedText),
      prefixIcon: Icon(icon),
      prefixIconColor: const Color(0xFFD8D1C8),
      filled: true,
      fillColor: const Color(0xAA06121D),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF748395)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.premiumCyan, width: 1.4),
      ),
    );
  }

  Future<void> _createGame() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _createdSession = null;
    });
    try {
      final session = await _repository.createOnlineGame(
        hostPlayerName: _nameController.text,
        hostColorValue: _selectedColorValue,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _createdSession = session;
        _isBusy = false;
      });
      _watchWaitingRoom(session);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _joinGame() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final session = await _repository.joinOnlineGame(
        gameId: _codeController.text,
        playerName: _nameController.text,
        playerColorValue: _selectedColorValue,
      );
      if (!mounted) {
        return;
      }
      _openOnlineGame(session);
    } catch (error) {
      _showError(error);
    }
  }

  void _watchWaitingRoom(OnlineGameSession session) {
    _waitingSubscription?.cancel();
    _waitingSubscription = _repository
        .watchOnlineGame(
          gameId: session.gameId,
          localPlayerId: session.localPlayerId,
        )
        .listen((updatedSession) {
          if (!mounted || updatedSession == null || !updatedSession.isActive) {
            return;
          }
          _openOnlineGame(updatedSession);
        });
  }

  void _openOnlineGame(OnlineGameSession session) {
    _waitingSubscription?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          initialState: session.state,
          onlineRepository: _repository,
          localPlayerId: session.localPlayerId,
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    });
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 54,
        height: 54,
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
            ? const Icon(Icons.check, color: Colors.white, size: 28)
            : null,
      ),
    );
  }
}
