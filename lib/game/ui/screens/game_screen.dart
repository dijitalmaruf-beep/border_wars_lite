import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../engine/game_engine.dart';
import '../../models/game_state.dart';
import '../widgets/attack_dialog.dart';
import '../widgets/player_status_bar.dart';
import '../widgets/selected_territory_panel.dart';
import '../widgets/territory_map.dart';
import '../widgets/turn_panel.dart';
import 'victory_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.initialState, super.key});

  final GameState initialState;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = const GameEngine();
  final Random _random = Random();

  late GameState _state;
  Timer? _botTimer;
  bool _isBotThinking = false;
  bool _navigatedToVictory = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterStateChanged());
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAttack = _state.selectedSourceId != null &&
        _state.selectedTargetId != null &&
        _engine.canAttack(
          _state,
          sourceId: _state.selectedSourceId!,
          targetId: _state.selectedTargetId!,
        );
    final winChance = canAttack ? _engine.winChanceForSelection(_state) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Wars Lite'),
        backgroundColor: AppColors.screenBackground,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final sidePanel = _SidePanel(
              state: _state,
              canAttack: canAttack,
              winChance: winChance,
              isBotThinking: _isBotThinking,
              onAttack: _handleAttack,
              onEndTurn: _handleEndTurn,
            );

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: _MapSection(
                        state: _state,
                        onTerritoryTap: _handleTerritoryTap,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 350, child: sidePanel),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                SizedBox(
                  height: min(520.0, max(360.0, constraints.maxWidth * 0.94)),
                  child: _MapSection(
                    state: _state,
                    onTerritoryTap: _handleTerritoryTap,
                  ),
                ),
                const SizedBox(height: 12),
                sidePanel,
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleTerritoryTap(String territoryId) {
    if (_state.currentPlayer.isBot || _state.winnerId != null) {
      return;
    }
    _setGameState(_engine.selectTerritory(_state, territoryId));
  }

  Future<void> _handleAttack() async {
    final source = _state.territoryByIdOrNull(_state.selectedSourceId);
    final target = _state.territoryByIdOrNull(_state.selectedTargetId);
    if (source == null || target == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AttackDialog(
        source: source,
        target: target,
        winChance: _engine.winChanceForSelection(_state),
      ),
    );

    if (confirmed == true && mounted) {
      _setGameState(_engine.attackSelected(_state, random: _random));
    }
  }

  void _handleEndTurn() {
    if (_state.currentPlayer.isBot || _state.winnerId != null) {
      return;
    }
    _setGameState(_engine.endTurn(_state));
  }

  void _setGameState(GameState nextState) {
    setState(() {
      _state = nextState;
    });
    _afterStateChanged();
  }

  void _afterStateChanged() {
    if (!mounted) {
      return;
    }

    if (_state.winnerId != null) {
      _goToVictory();
      return;
    }

    if (_state.currentPlayer.isBot && !_isBotThinking) {
      _scheduleBotTurn();
    }
  }

  void _scheduleBotTurn() {
    _botTimer?.cancel();
    setState(() {
      _isBotThinking = true;
      _state = _state.copyWith(
        statusMessage: '${_state.currentPlayer.name} is planning...',
      );
    });

    _botTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) {
        return;
      }
      final nextState = _engine.runBotTurn(_state, random: _random);
      setState(() {
        _state = nextState;
        _isBotThinking = false;
      });
      _afterStateChanged();
    });
  }

  void _goToVictory() {
    if (_navigatedToVictory) {
      return;
    }
    _navigatedToVictory = true;
    final winner = _state.playerById(_state.winnerId);
    if (winner == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VictoryScreen(
            winner: winner,
            territoryCount: _state.ownedTerritoryCount(winner.id),
          ),
        ),
      );
    });
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.state,
    required this.onTerritoryTap,
  });

  final GameState state;
  final ValueChanged<String> onTerritoryTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TerritoryMap(
          state: state,
          onTerritoryTap: onTerritoryTap,
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.state,
    required this.canAttack,
    required this.winChance,
    required this.isBotThinking,
    required this.onAttack,
    required this.onEndTurn,
  });

  final GameState state;
  final bool canAttack;
  final double winChance;
  final bool isBotThinking;
  final VoidCallback onAttack;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PlayerStatusBar(state: state),
          const SizedBox(height: 12),
          TurnPanel(
            state: state,
            isBotThinking: isBotThinking,
            onEndTurn: onEndTurn,
          ),
          const SizedBox(height: 12),
          SelectedTerritoryPanel(
            state: state,
            canAttack: canAttack,
            winChance: winChance,
            onAttack: onAttack,
          ),
        ],
      ),
    );
  }
}
