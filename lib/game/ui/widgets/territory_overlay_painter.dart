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
  final Map<String, List<Path>> territoryPaths;
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
      final paths = territoryPaths[territory.id] ?? const <Path>[];
      if (paths.isEmpty) {
        continue;
      }

      final owner = state.playerById(territory.ownerId);
      final isValidTarget =
          source != null &&
          source.neighbors.contains(territory.id) &&
          territory.ownerId != state.currentPlayer.id;

      if (owner != null) {
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = Color(owner.colorValue).withValues(alpha: 0.32);
        for (final path in paths) {
          canvas.drawPath(path, paint);
        }
      } else {
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.neutral.withValues(alpha: 0.08);
        for (final path in paths) {
          canvas.drawPath(path, paint);
        }
      }

      if (isValidTarget) {
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD66D).withValues(alpha: 0.18);
        for (final path in paths) {
          canvas.drawPath(path, paint);
        }
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
    final paths = territoryPaths[territoryId] ?? const <Path>[];
    if (paths.isEmpty) {
      return;
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(4.0, size.width * 0.006)
      ..color = glowColor.withValues(alpha: 0.70)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.outer, 4);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * 0.0028)
      ..color = color;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.82);

    for (final path in paths) {
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, strokePaint);
      canvas.drawPath(path, innerPaint);
    }
  }

  void _paintArmyLabels(Canvas canvas, Size size) {
    final fontSize = (size.width * 0.008).clamp(8.0, 10.0).toDouble();

    for (final territory in state.territories) {
      final center = Offset(
        territory.x * size.width,
        territory.y * size.height,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: territory.armyCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: const <Shadow>[Shadow(color: Colors.black, blurRadius: 5)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = math.max(18.0, textPainter.width + 8);
      final chipHeight = math.max(13.0, textPainter.height + 3);
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
