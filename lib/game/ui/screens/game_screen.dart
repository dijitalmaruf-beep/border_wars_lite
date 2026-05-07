import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../engine/game_engine.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/territory.dart';
import '../widgets/attack_dialog.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import '../widgets/territory_map.dart';
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
      body: PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth >= 720 ? 720.0 : double.infinity;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _WorldHeader(state: _state),
                        const SizedBox(height: 8),
                        _PlayerStrip(state: _state),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _MapStage(
                            state: _state,
                            onTerritoryTap: _handleTerritoryTap,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _BattleCommandPanel(
                          state: _state,
                          canAttack: canAttack,
                          winChance: winChance,
                          isBotThinking: _isBotThinking,
                          onAttack: _handleAttack,
                          onEndTurn: _handleEndTurn,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu),
            color: AppColors.premiumText,
            tooltip: 'Menu',
          ),
          const Expanded(
            child: Text(
              'BORDER WARS LITE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.premiumText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            'TURN ${state.turnNumber}',
            style: const TextStyle(
              color: AppColors.premiumMutedText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.hourglass_empty, color: AppColors.premiumText, size: 18),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          itemBuilder: (context, index) {
            final player = state.players[index];
            return _PlayerCard(
              player: player,
              isCurrent: player.id == state.currentPlayer.id,
              territoryCount: state.ownedTerritoryCount(player.id),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: state.players.length,
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isCurrent,
    required this.territoryCount,
  });

  final Player player;
  final bool isCurrent;
  final int territoryCount;

  @override
  Widget build(BuildContext context) {
    final color = Color(player.colorValue);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withValues(alpha: 0.20)
            : const Color(0x66111B25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? color.withValues(alpha: 0.95)
              : AppColors.premiumBorder.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.premiumText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '$territoryCount ★',
            style: const TextStyle(
              color: Color(0xFFFFD27A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStage extends StatelessWidget {
  const _MapStage({
    required this.state,
    required this.onTerritoryTap,
  });

  final GameState state;
  final ValueChanged<String> onTerritoryTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.premiumBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.premiumCyan.withValues(alpha: 0.16),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TerritoryMap(
                state: state,
                onTerritoryTap: onTerritoryTap,
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 14,
          child: Column(
            children: const <Widget>[
              _MapToolButton(icon: Icons.my_location, tooltip: 'Focus'),
              SizedBox(height: 8),
              _MapToolButton(icon: Icons.search, tooltip: 'Search'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xCC07131F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.premiumBorder),
        ),
        child: Icon(icon, color: AppColors.premiumText),
      ),
    );
  }
}

class _BattleCommandPanel extends StatelessWidget {
  const _BattleCommandPanel({
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
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    final percent = (winChance * 100).round();
    final canEndTurn = !state.currentPlayer.isBot && state.winnerId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PremiumPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TerritoryReadout(
                      label: 'SOURCE',
                      labelColor: const Color(0xFF55B9FF),
                      territory: source,
                      state: state,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: AppColors.premiumText, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TerritoryReadout(
                      label: 'TARGET',
                      labelColor: AppColors.premiumRed,
                      territory: target,
                      state: state,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _WinChance(percent: percent, enabled: canAttack),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isBotThinking ? 'Bot turn in progress...' : state.statusMessage,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.premiumMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: PremiumButton(
                label: 'REINFORCE',
                icon: Icons.shield,
                onPressed: null,
                tone: PremiumButtonTone.blue,
                height: 50,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PremiumButton(
                label: 'ATTACK',
                icon: Icons.sports_martial_arts,
                onPressed: canAttack ? onAttack : null,
                tone: PremiumButtonTone.red,
                height: 50,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PremiumButton(
                label: 'TRANSFER',
                icon: Icons.swap_horiz,
                onPressed: null,
                tone: PremiumButtonTone.teal,
                height: 50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PremiumButton(
          label: 'END TURN',
          icon: Icons.hourglass_bottom,
          onPressed: canEndTurn ? onEndTurn : null,
          tone: PremiumButtonTone.gold,
          height: 58,
        ),
      ],
    );
  }
}

class _TerritoryReadout extends StatelessWidget {
  const _TerritoryReadout({
    required this.label,
    required this.labelColor,
    required this.territory,
    required this.state,
  });

  final String label;
  final Color labelColor;
  final Territory? territory;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final owner = state.playerById(territory?.ownerId);
    final ownerColor = owner == null ? AppColors.neutral : Color(owner.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          territory?.name ?? 'None',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.premiumText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            Icon(Icons.shield, color: ownerColor, size: 16),
            const SizedBox(width: 5),
            Text(
              territory?.armyCount.toString() ?? '-',
              style: const TextStyle(
                color: AppColors.premiumText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WinChance extends StatelessWidget {
  const _WinChance({
    required this.percent,
    required this.enabled,
  });

  final int percent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF91F05B) : AppColors.premiumMutedText;
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const Text(
            'WIN CHANCE',
            style: TextStyle(
              color: Color(0xFFFFD66D),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            enabled ? '$percent%' : '--',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            enabled ? 'Good Advantage' : 'Select target',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
