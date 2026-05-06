import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/player.dart';
import '../../models/territory.dart';

class TerritoryTile extends StatelessWidget {
  const TerritoryTile({
    required this.territory,
    required this.owner,
    required this.size,
    required this.isSelectedSource,
    required this.isSelectedTarget,
    required this.isNeighborCandidate,
    required this.onTap,
    super.key,
  });

  final Territory territory;
  final Player? owner;
  final double size;
  final bool isSelectedSource;
  final bool isSelectedTarget;
  final bool isNeighborCandidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = owner == null ? AppColors.neutral : Color(owner!.colorValue);
    final borderColor = isSelectedSource
        ? Colors.white
        : isSelectedTarget
            ? AppColors.danger
            : isNeighborCandidate
                ? const Color(0xFFFFF7AD)
                : const Color(0x66000000);

    return Tooltip(
      message: '${territory.name} - ${owner?.name ?? 'Neutral'}',
      child: Semantics(
        button: true,
        label: territory.name,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: isSelectedSource || isSelectedTarget ? 4 : 2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${territory.armyCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
