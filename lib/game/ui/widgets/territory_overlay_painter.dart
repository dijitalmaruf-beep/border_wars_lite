import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';

class TerritoryOverlayPainter extends CustomPainter {
  const TerritoryOverlayPainter({
    required this.state,
    required this.territoryPaths,
    this.paintOwnership = false,
    this.paintLabelsAndHighlights = false,
  });

  final GameState state;
  final Map<String, Path> territoryPaths;
  final bool paintOwnership;
  final bool paintLabelsAndHighlights;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintOwnership) {
      _paintOwnership(canvas);
    }
    if (paintLabelsAndHighlights) {
      _paintHighlights(canvas, size);
      _paintArmyLabels(canvas, size);
    }
  }

  void _paintOwnership(Canvas canvas) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    for (final territory in state.territories) {
      final path = territoryPaths[territory.id];
      if (path == null) {
        continue;
      }

      final owner = state.playerById(territory.ownerId);
      final isValidTarget = source != null &&
          source.neighbors.contains(territory.id) &&
          territory.ownerId != state.currentPlayer.id;

      if (owner != null) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Color(owner.colorValue).withValues(alpha: 0.34),
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = AppColors.neutral.withValues(alpha: 0.10),
        );
      }

      if (isValidTarget) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFFD66D).withValues(alpha: 0.20),
        );
      }
    }
  }

  void _paintHighlights(Canvas canvas, Size size) {
    _paintHighlight(
      canvas,
      state.selectedSourceId,
      color: const Color(0xFF2A91FF),
      glowColor: const Color(0xFF00A8FF),
      size: size,
    );
    _paintHighlight(
      canvas,
      state.selectedTargetId,
      color: AppColors.premiumRed,
      glowColor: AppColors.premiumRed,
      size: size,
    );
  }

  void _paintHighlight(
    Canvas canvas,
    String? territoryId, {
    required Color color,
    required Color glowColor,
    required Size size,
  }) {
    if (territoryId == null) {
      return;
    }
    final path = territoryPaths[territoryId];
    if (path == null) {
      return;
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(5.0, size.width * 0.009)
        ..color = glowColor.withValues(alpha: 0.72)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.outer, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, size.width * 0.0042)
        ..color = color,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.88),
    );
  }

  void _paintArmyLabels(Canvas canvas, Size size) {
    final fontSize = (size.width * 0.012).clamp(10.0, 14.0).toDouble();

    for (final territory in state.territories) {
      final center = Offset(territory.x * size.width, territory.y * size.height);
      final textPainter = TextPainter(
        text: TextSpan(
          text: territory.armyCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: const <Shadow>[
              Shadow(color: Colors.black, blurRadius: 5),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = math.max(24.0, textPainter.width + 12);
      final chipHeight = math.max(18.0, textPainter.height + 6);
      final rect = Rect.fromCenter(
        center: center,
        width: chipWidth,
        height: chipHeight,
      );
      const radius = Radius.circular(6);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = const Color(0xD8051019),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.48),
      );

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TerritoryOverlayPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.territoryPaths != territoryPaths ||
        oldDelegate.paintOwnership != paintOwnership ||
        oldDelegate.paintLabelsAndHighlights != paintLabelsAndHighlights;
  }
}
