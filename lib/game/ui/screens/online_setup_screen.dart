import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../services/firebase/firebase_service.dart';
import '../../../services/firebase/firestore_game_repository.dart';
import '../../models/player.dart';
import '../widgets/commander_banner_picker.dart';
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
  int _selectedMaxHumanPlayers = GameConstants.maxOnlineHumanPlayers;
  int _selectedBotCount = 2;
  bool _isBusy = false;
  String? _errorMessage;

  bool get _hasJoinCode => _codeController.text.trim().isNotEmpty;

  bool get _hasValidJoinCode {
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(_normalizedRoomCode);
  }

  String get _normalizedRoomCode => _codeController.text.trim().toUpperCase();

  @override
  void dispose() {
    _waitingSubscription?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canJoinRoom =
        _canUseOnline && !_isBusy && _createdSession == null;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 10),
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
                      const SizedBox(height: 18),
                      const Text(
                        'ONLINE SAVAŞ ODASI',
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
                        'Oda kodu oluştur veya mevcut bir odaya katıl.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!FirebaseService.isAvailable) ...<Widget>[
                        PremiumPanel(
                          borderColor: AppColors.premiumRed,
                          padding: const EdgeInsets.all(14),
                          child: const Text(
                            'Firebase bu build için yapılandırılmamış. '
                            'Android/Web config dosyaları eklenince Online Oyun '
                            'otomatik aktif olur.',
                            style: TextStyle(
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('KOMUTAN ADI'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameController,
                              enabled: !_isBusy && _createdSession == null,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: AppColors.premiumText,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Komutan adını gir...',
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _PanelLabel('SANCAĞINI SEÇ'),
                            const SizedBox(height: 14),
                            CommanderBannerPicker(
                              colorValues: AppColors.humanColorValues,
                              selectedColorValue: _selectedColorValue,
                              enabled: !_isBusy && _createdSession == null,
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _PanelLabel('OYUNCU SAYISI'),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                _StepperButton(
                                  icon: Icons.remove,
                                  onPressed:
                                      !_isBusy &&
                                          _createdSession == null &&
                                          _selectedMaxHumanPlayers > 2
                                      ? () => _changeMaxHumanPlayers(-1)
                                      : null,
                                ),
                                Expanded(
                                  child: Column(
                                    children: <Widget>[
                                      Text(
                                        '$_selectedMaxHumanPlayers',
                                        style: const TextStyle(
                                          color: AppColors.premiumText,
                                          fontSize: 30,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'oda kapasitesi',
                                        style: TextStyle(
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
                                      !_isBusy &&
                                          _createdSession == null &&
                                          _selectedMaxHumanPlayers <
                                              GameConstants
                                                  .maxOnlineHumanPlayers
                                      ? () => _changeMaxHumanPlayers(1)
                                      : null,
                                ),
                              ],
                            ),
                            Slider(
                              value: _selectedMaxHumanPlayers.toDouble(),
                              min: 2,
                              max: GameConstants.maxOnlineHumanPlayers
                                  .toDouble(),
                              divisions:
                                  GameConstants.maxOnlineHumanPlayers - 2,
                              activeColor: AppColors.premiumGold,
                              inactiveColor: AppColors.premiumBorder,
                              onChanged: _isBusy || _createdSession != null
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedMaxHumanPlayers = value
                                            .round();
                                      });
                                    },
                            ),
                            const SizedBox(height: 14),
                            const _PanelLabel('BOT KOMUTANLAR'),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                _StepperButton(
                                  icon: Icons.remove,
                                  onPressed:
                                      !_isBusy &&
                                          _createdSession == null &&
                                          _selectedBotCount > 0
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
                                          fontSize: 30,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'odadaki bot',
                                        style: TextStyle(
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
                                      !_isBusy &&
                                          _createdSession == null &&
                                          _selectedBotCount <
                                              GameConstants.maxBotPlayers
                                      ? () => _changeBotCount(1)
                                      : null,
                                ),
                              ],
                            ),
                            Slider(
                              value: _selectedBotCount.toDouble(),
                              min: 0,
                              max: GameConstants.maxBotPlayers.toDouble(),
                              divisions: GameConstants.maxBotPlayers,
                              activeColor: AppColors.premiumCyan,
                              inactiveColor: AppColors.premiumBorder,
                              onChanged: _isBusy || _createdSession != null
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedBotCount = value.round();
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumPanel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _PanelLabel('ODA KODU İLE KATIL'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              enabled: !_isBusy && _createdSession == null,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              onChanged: (_) {
                                setState(() {
                                  if (_errorMessage?.startsWith('Oda kodu') ??
                                      false) {
                                    _errorMessage = null;
                                  }
                                });
                              },
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
                              label: 'ONLINE OYUNA KATIL',
                              icon: Icons.login,
                              onPressed: canJoinRoom ? _joinGame : null,
                              tone: _hasJoinCode
                                  ? PremiumButtonTone.teal
                                  : PremiumButtonTone.dark,
                              height: 52,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumButton(
                        label: _isBusy ? 'BAĞLANIYOR...' : 'ODA KUR',
                        icon: Icons.add_link,
                        onPressed:
                            _canUseOnline && !_isBusy && _createdSession == null
                            ? _createGame
                            : null,
                        tone: PremiumButtonTone.blue,
                        height: 58,
                      ),
                      if (_createdSession != null) ...<Widget>[
                        const SizedBox(height: 16),
                        PremiumPanel(
                          borderColor: AppColors.premiumGold,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: <Widget>[
                              const Text(
                                'SAVAŞ ODASI KODU',
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
                              _LobbyPlayerList(
                                players: _createdSession!.humanPlayers,
                                maxPlayers: _createdSession!.maxHumanPlayers,
                              ),
                              const SizedBox(height: 10),
                              if (_createdSession!.isHost) ...<Widget>[
                                PremiumButton(
                                  label: _isBusy
                                      ? 'BAŞLIYOR...'
                                      : 'ONLINE SAVAŞI BAŞLAT',
                                  icon: Icons.play_arrow,
                                  onPressed:
                                      !_isBusy &&
                                          _createdSession!
                                                  .humanPlayers
                                                  .length >=
                                              2
                                      ? _startGame
                                      : null,
                                  tone: PremiumButtonTone.gold,
                                  height: 52,
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: _createdSession!.gameId,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Kodu Kopyala'),
                              ),
                              const Text(
                                'Bu kodu paylaş. Komutanlar hazır olunca ev sahibi oyunu başlatır.',
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
        botCount: _selectedBotCount,
        maxHumanPlayers: _selectedMaxHumanPlayers,
      );
      if (!mounted) {
        return;
      }
      final assignedColor = _assignedColorFor(session);
      setState(() {
        if (assignedColor != null) {
          _selectedColorValue = assignedColor;
        }
        _createdSession = session;
        _isBusy = false;
      });
      _watchWaitingRoom(session);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _joinGame() async {
    final roomCode = _normalizedRoomCode;
    if (!_hasValidJoinCode) {
      setState(() {
        _errorMessage = roomCode.isEmpty
            ? 'Oda kodunu gir.'
            : 'Oda kodu 6 harf veya rakam olmalı.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final session = await _repository.joinOnlineGame(
        gameId: roomCode,
        playerName: _nameController.text,
        playerColorValue: _selectedColorValue,
      );
      if (!mounted) {
        return;
      }
      final assignedColor = _assignedColorFor(session);
      final colorChanged =
          assignedColor != null && assignedColor != _selectedColorValue;
      setState(() {
        if (assignedColor != null) {
          _selectedColorValue = assignedColor;
        }
        _createdSession = session;
        _isBusy = false;
      });
      if (colorChanged) {
        _showColorReassignedNotice();
      }
      _watchWaitingRoom(session);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _startGame() async {
    final session = _createdSession;
    if (session == null || !session.isHost) {
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final activeSession = await _repository.startOnlineGame(session.gameId);
      if (!mounted) {
        return;
      }
      _openOnlineGame(activeSession);
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
          if (!mounted || updatedSession == null) {
            return;
          }
          if (!updatedSession.isActive) {
            setState(() {
              final assignedColor = _assignedColorFor(updatedSession);
              if (assignedColor != null) {
                _selectedColorValue = assignedColor;
              }
              _createdSession = updatedSession;
              _isBusy = false;
            });
            return;
          }
          _openOnlineGame(updatedSession);
        }, onError: _showError);
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

  int? _assignedColorFor(OnlineGameSession session) {
    for (final player in session.humanPlayers) {
      if (player.id == session.localPlayerId) {
        return player.colorValue;
      }
    }
    return null;
  }

  void _showColorReassignedNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Seçtiğin renk odada kullanılıyordu. Sana uygun boş bir renk atandı.',
        ),
      ),
    );
  }

  void _changeBotCount(int delta) {
    setState(() {
      _selectedBotCount = (_selectedBotCount + delta)
          .clamp(0, GameConstants.maxBotPlayers)
          .toInt();
    });
  }

  void _changeMaxHumanPlayers(int delta) {
    setState(() {
      _selectedMaxHumanPlayers = (_selectedMaxHumanPlayers + delta)
          .clamp(2, GameConstants.maxOnlineHumanPlayers)
          .toInt();
    });
  }
}

class _LobbyPlayerList extends StatelessWidget {
  const _LobbyPlayerList({required this.players, required this.maxPlayers});

  final List<Player> players;
  final int maxPlayers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Komutanlar ${players.length}/$maxPlayers',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.premiumMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: players.map((player) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xB006121D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(player.colorValue).withValues(alpha: 0.80),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CommanderBannerBadge(colorValue: player.colorValue),
                  const SizedBox(width: 6),
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: AppColors.premiumText,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
      width: 44,
      height: 44,
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
