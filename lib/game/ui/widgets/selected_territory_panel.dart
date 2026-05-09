import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';
import '../../models/territory.dart';

class SelectedTerritoryPanel extends StatelessWidget {
  const SelectedTerritoryPanel({
    required this.state,
    required this.canAttack,
    required this.winChance,
    required this.onAttack,
    super.key,
  });

  final GameState state;
  final bool canAttack;
  final double winChance;
  final VoidCallback onAttack;

  @override
  Widget build(BuildContext context) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    final percent = (winChance * 100).round();

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
            const Text(
              'Seçim',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _TerritorySummary(label: 'Kaynak', territory: source, state: state),
            const SizedBox(height: 8),
            _TerritorySummary(label: 'Hedef', territory: target, state: state),
            const SizedBox(height: 14),
            if (canAttack) ...<Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.percent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kazanma şansı: %$percent',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAttack,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Saldır'),
              ),
            ] else
              const Text(
                'Kaynak ve komşu düşman hedef seç.',
                style: TextStyle(color: AppColors.mutedInk),
              ),
          ],
        ),
      ),
    );
  }
}

class _TerritorySummary extends StatelessWidget {
  const _TerritorySummary({
    required this.label,
    required this.territory,
    required this.state,
  });

  final String label;
  final Territory? territory;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final owner = state.playerById(territory?.ownerId);
    final ownerColor = owner == null
        ? AppColors.neutral
        : Color(owner.colorValue);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: territory == null ? AppColors.panelBorder : ownerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  territory?.name ?? 'Yok',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (territory != null)
            Text(
              '${territory!.armyCount}',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}
