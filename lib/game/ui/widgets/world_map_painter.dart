import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';

class WorldMapPainter extends CustomPainter {
  const WorldMapPainter({
    required this.state,
    required this.territoryPaths,
  });

  final GameState state;
  final Map<String, Path> territoryPaths;

  @override
  void paint(Canvas canvas, Size size) {
    _paintOcean(canvas, size);
    _paintGraticule(canvas, size);
    _paintTerritories(canvas, size);
    _paintArmyLabels(canvas, size);
  }

  void _paintOcean(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF0B5870),
          Color(0xFF0E6F85),
          Color(0xFF134F68),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintGraticule(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    for (var x = 0.1; x < 1.0; x += 0.1) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x, size.height),
        paint,
      );
    }
    for (var y = 0.2; y < 1.0; y += 0.2) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        paint,
      );
    }
  }

  void _paintTerritories(Canvas canvas, Size size) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, size.width * 0.0015)
      ..color = const Color(0xFF14333A);

    for (final territory in state.territories) {
      final path = territoryPaths[territory.id];
      if (path == null) {
        continue;
      }

      final owner = state.playerById(territory.ownerId);
      final fillColor = owner == null ? AppColors.neutral : Color(owner.colorValue);
      final isSelectedSource = territory.id == state.selectedSourceId;
      final isSelectedTarget = territory.id == state.selectedTargetId;
      final isValidTarget = source != null &&
          source.neighbors.contains(territory.id) &&
          territory.ownerId != state.currentPlayer.id;

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = fillColor.withValues(alpha: owner == null ? 0.70 : 0.82),
      );

      if (isValidTarget) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFFF7AD).withValues(alpha: 0.28),
        );
      }

      canvas.drawPath(path, borderPaint);

      if (isSelectedSource || isSelectedTarget) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelectedTarget ? 3.2 : 3.6
            ..color = isSelectedTarget ? AppColors.danger : Colors.white,
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF0B1720),
        );
      }
    }
  }

  void _paintArmyLabels(Canvas canvas, Size size) {
    final fontSize = (size.width * 0.017).clamp(10.0, 15.0).toDouble();

    for (final territory in state.territories) {
      final center = Offset(territory.x * size.width, territory.y * size.height);
      final textPainter = TextPainter(
        text: TextSpan(
          text: territory.armyCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = math.max(24.0, textPainter.width + 13);
      final chipHeight = math.max(20.0, textPainter.height + 7);
      final rect = Rect.fromCenter(
        center: center,
        width: chipWidth,
        height: chipHeight,
      );
      final radius = Radius.circular(chipHeight / 2);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = const Color(0xCC17211A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.72),
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
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.territoryPaths != territoryPaths;
  }
}
