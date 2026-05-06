import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';
import '../../models/territory.dart';
import 'territory_tile.dart';

class TerritoryMap extends StatelessWidget {
  const TerritoryMap({
    required this.state,
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
  final ValueChanged<String> onTerritoryTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final tileSize = math.min(56.0, math.max(42.0, width * 0.09));
        final territoryMap = <String, Territory>{
          for (final territory in state.territories) territory.id: territory,
        };
        final source = state.territoryByIdOrNull(state.selectedSourceId);

        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.mapOcean),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapBackgroundPainter(),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _NeighborLinesPainter(state: state),
                ),
              ),
              for (final territory in state.territories)
                Positioned(
                  left: (territory.x * width - tileSize / 2)
                      .clamp(0, math.max(0, width - tileSize))
                      .toDouble(),
                  top: (territory.y * height - tileSize / 2)
                      .clamp(0, math.max(0, height - tileSize))
                      .toDouble(),
                  child: TerritoryTile(
                    territory: territory,
                    owner: state.playerById(territory.ownerId),
                    size: tileSize,
                    isSelectedSource: territory.id == state.selectedSourceId,
                    isSelectedTarget: territory.id == state.selectedTargetId,
                    isNeighborCandidate:
                        source?.neighbors.contains(territory.id) ?? false,
                    onTap: () => onTerritoryTap(territory.id),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${territoryMap.length} territories',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()..color = AppColors.mapLand;
    final accentPaint = Paint()..color = AppColors.mapLandAccent;

    final mainLand = Path()
      ..moveTo(size.width * 0.05, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.02,
        size.width * 0.46,
        size.height * 0.09,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.02,
        size.width * 0.94,
        size.height * 0.22,
      )
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.52,
        size.width * 0.86,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.98,
        size.width * 0.22,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.00,
        size.height * 0.68,
        size.width * 0.05,
        size.height * 0.16,
      )
      ..close();

    final westernIsland = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.12, size.height * 0.58),
          width: size.width * 0.24,
          height: size.height * 0.28,
        ),
      );

    final easternIsland = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.58),
          width: size.width * 0.22,
          height: size.height * 0.30,
        ),
      );

    canvas.drawPath(mainLand, landPaint);
    canvas.drawPath(westernIsland, accentPaint);
    canvas.drawPath(easternIsland, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) => false;
}

class _NeighborLinesPainter extends CustomPainter {
  const _NeighborLinesPainter({required this.state});

  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final territories = <String, Territory>{
      for (final territory in state.territories) territory.id: territory,
    };
    final drawnPairs = <String>{};

    for (final territory in state.territories) {
      for (final neighborId in territory.neighbors) {
        final neighbor = territories[neighborId];
        if (neighbor == null) {
          continue;
        }
        final pair = <String>[territory.id, neighbor.id]..sort();
        final pairKey = pair.join(':');
        if (!drawnPairs.add(pairKey)) {
          continue;
        }

        canvas.drawLine(
          Offset(territory.x * size.width, territory.y * size.height),
          Offset(neighbor.x * size.width, neighbor.y * size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeighborLinesPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
