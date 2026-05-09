import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';

class TerritoryOverlayPainter extends CustomPainter {
  const TerritoryOverlayPainter({
    required this.state,
    required this.territoryPaths,
    required this.territoryHighlightPaths,
    required this.territoryLabelAnchors,
    required this.validSourceIds,
    required this.validTargetIds,
    this.mapZoom = 1.0,
    this.paintOwnership = false,
    this.paintLabelsAndHighlights = false,
  });

  final GameState state;
  final Map<String, List<Path>> territoryPaths;
  final Map<String, Path> territoryHighlightPaths;
  final Map<String, Offset> territoryLabelAnchors;
  final Set<String> validSourceIds;
  final Set<String> validTargetIds;
  final double mapZoom;
  final bool paintOwnership;
  final bool paintLabelsAndHighlights;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintOwnership) {
      _paintOwnership(canvas, size);
    }
    if (paintLabelsAndHighlights) {
      _paintHighlights(canvas, size);
      _paintArmyLabels(canvas, size);
    }
  }

  void _paintOwnership(Canvas canvas, Size size) {
    for (final territory in state.territories) {
      final paths = territoryPaths[territory.id] ?? const <Path>[];
      if (paths.isEmpty) {
        continue;
      }

      final owner = state.playerById(territory.ownerId);
      final isValidSource = validSourceIds.contains(territory.id);
      final isValidTarget = validTargetIds.contains(territory.id);

      if (owner != null) {
        final ownerColor = Color(owner.colorValue);
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = ownerColor.withValues(alpha: 0.55);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.62)
          ..color = ownerColor.withValues(alpha: 0.34);
        for (final path in paths) {
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
        }
      } else {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF7C8790).withValues(alpha: 0.22);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.7)
          ..color = Colors.white.withValues(alpha: 0.23);
        for (final path in paths) {
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
        }
      }

      if (isValidSource) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 1.0)
          ..color = AppColors.premiumCyan.withValues(alpha: 0.50);
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.premiumCyan.withValues(alpha: 0.08);
        for (final path in paths) {
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, paint);
        }
      }

      if (isValidTarget) {
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD66D).withValues(alpha: 0.16);
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
    final path = territoryHighlightPaths[territoryId] ?? _combinedPath(paths);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 5.2)
      ..color = glowColor.withValues(alpha: 0.70)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.outer, 4 / _effectiveZoom);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 2.3)
      ..color = color;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / _effectiveZoom
      ..color = Colors.white.withValues(alpha: 0.82);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
    canvas.drawPath(path, innerPaint);
  }

  void _paintArmyLabels(Canvas canvas, Size size) {
    final zoom = _effectiveZoom;
    final visualFontSize = (9.8 - (zoom - 1) * 0.95).clamp(7.5, 10.2);
    final fontSize = visualFontSize / zoom;
    final paddingX = (5.8 / zoom).clamp(1.6, 6.4);
    final paddingY = (3.0 / zoom).clamp(0.9, 3.6);
    final minChipWidth = 18.0 / zoom;
    final minChipHeight = 14.0 / zoom;
    final radius = Radius.circular(5 / zoom);
    final placedRects = <Rect>[];

    for (final territory in state.territories) {
      final owner = state.playerById(territory.ownerId);
      final isSelected =
          state.selectedSourceId == territory.id ||
          state.selectedTargetId == territory.id;
      final isActionable =
          isSelected ||
          validSourceIds.contains(territory.id) ||
          validTargetIds.contains(territory.id);
      if (owner == null && zoom < 1.16 && !isActionable) {
        continue;
      }

      final anchor =
          territoryLabelAnchors[territory.id] ??
          Offset(territory.x * size.width, territory.y * size.height);
      final ownerColor = owner == null
          ? Colors.white.withValues(alpha: 0.52)
          : Color(owner.colorValue);
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

      final chipWidth = math.max(
        minChipWidth,
        textPainter.width + paddingX * 2,
      );
      final chipHeight = math.max(
        minChipHeight,
        textPainter.height + paddingY * 2,
      );
      final center = _labelCenterAvoidingCollisions(
        territory.id,
        anchor,
        Size(chipWidth, chipHeight),
        placedRects,
      );
      final rect = Rect.fromCenter(
        center: center,
        width: chipWidth,
        height: chipHeight,
      );
      placedRects.add(rect.inflate(1.5 / zoom));

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = const Color(0xDD051019)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.outer,
            owner == null ? 1.0 / zoom : 1.9 / zoom,
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xE6051019),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75 / zoom
          ..color = ownerColor.withValues(alpha: owner == null ? 0.28 : 0.78),
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
        oldDelegate.territoryHighlightPaths != territoryHighlightPaths ||
        oldDelegate.territoryLabelAnchors != territoryLabelAnchors ||
        oldDelegate.validSourceIds != validSourceIds ||
        oldDelegate.validTargetIds != validTargetIds ||
        oldDelegate.mapZoom != mapZoom ||
        oldDelegate.paintOwnership != paintOwnership ||
        oldDelegate.paintLabelsAndHighlights != paintLabelsAndHighlights;
  }

  double get _effectiveZoom => mapZoom.clamp(0.75, 4.0).toDouble();

  double _scaledStroke(Size size, double visualWidth) {
    final mapAwareMinimum = size.width * 0.00045;
    return math.max(mapAwareMinimum, visualWidth / _effectiveZoom);
  }

  Offset _labelCenterAvoidingCollisions(
    String territoryId,
    Offset anchor,
    Size chipSize,
    List<Rect> placedRects,
  ) {
    final zoom = _effectiveZoom;
    final paths = territoryPaths[territoryId] ?? const <Path>[];
    final offsets = <Offset>[
      Offset.zero,
      Offset(0, -12 / zoom),
      Offset(0, 12 / zoom),
      Offset(-14 / zoom, 0),
      Offset(14 / zoom, 0),
      Offset(-12 / zoom, -10 / zoom),
      Offset(12 / zoom, 10 / zoom),
      Offset(12 / zoom, -10 / zoom),
      Offset(-12 / zoom, 10 / zoom),
    ];

    for (final offset in offsets) {
      final candidate = anchor + offset;
      if (!_pointInsideAnyPath(candidate, paths)) {
        continue;
      }
      final rect = Rect.fromCenter(
        center: candidate,
        width: chipSize.width,
        height: chipSize.height,
      );
      if (!placedRects.any((placed) => placed.overlaps(rect))) {
        return candidate;
      }
    }

    return anchor;
  }

  bool _pointInsideAnyPath(Offset point, List<Path> paths) {
    if (paths.isEmpty) {
      return true;
    }
    return paths.any((path) => path.contains(point));
  }

  Path _combinedPath(List<Path> paths) {
    if (paths.length == 1) {
      return paths.first;
    }

    var combined = Path()..addPath(paths.first, Offset.zero);
    for (final path in paths.skip(1)) {
      try {
        combined = Path.combine(ui.PathOperation.union, combined, path);
      } catch (_) {
        combined.addPath(path, Offset.zero);
      }
    }
    return combined;
  }
}
