import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';
import 'commander_banner_picker.dart';

class TurnPanel extends StatelessWidget {
  const TurnPanel({
    required this.state,
    required this.isBotThinking,
    required this.onEndTurn,
    super.key,
  });

  final GameState state;
  final bool isBotThinking;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    final currentPlayer = state.currentPlayer;
    final ownedCount = state.ownedTerritoryCount(currentPlayer.id);
    final canEndTurn = !currentPlayer.isBot && state.winnerId == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CommanderBannerBadge(colorValue: currentPlayer.colorValue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentPlayer.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatPill(
                  icon: Icons.sync,
                  label: state.phase.name.toUpperCase(),
                ),
                _StatPill(icon: Icons.map, label: '$ownedCount bölge'),
                _StatPill(
                  icon: Icons.add_circle,
                  label: '${state.remainingReinforcements} takviye',
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                isBotThinking ? 'Bot sırası oynanıyor...' : state.statusMessage,
                key: ValueKey<String>(
                  isBotThinking ? 'thinking' : state.statusMessage,
                ),
                style: const TextStyle(color: AppColors.mutedInk),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: canEndTurn ? onEndTurn : null,
              icon: const Icon(Icons.skip_next),
              label: const Text('Turu Bitir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.mutedInk),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
