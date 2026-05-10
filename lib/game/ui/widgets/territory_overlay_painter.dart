import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
    required this.controlledContinents,
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
  final Set<String> controlledContinents;
  final double mapZoom;
  final bool paintOwnership;
  final bool paintLabelsAndHighlights;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintOwnership) {
      _paintOwnership(canvas, size);
      _paintContinentBorders(canvas, size);
    }
    if (paintLabelsAndHighlights) {
      _paintHighlights(canvas, size);
      _paintArmyLabels(canvas, size);
    }
  }

  void _paintContinentBorders(Canvas canvas, Size size) {
    final pathsByContinent = <String, List<Path>>{};
    final colorByContinent = <String, Color>{};
    for (final territory in state.territories) {
      final paths = territoryPaths[territory.id] ?? const <Path>[];
      if (paths.isEmpty) {
        continue;
      }
      pathsByContinent
          .putIfAbsent(territory.continent, () => <Path>[])
          .addAll(paths);
      final owner = state.playerById(territory.ownerId);
      if (owner != null) {
        colorByContinent[territory.continent] = Color(owner.colorValue);
      }
    }

    for (final entry in pathsByContinent.entries) {
      final isControlled = controlledContinents.contains(entry.key);
      final color = colorByContinent[entry.key] ?? AppColors.premiumGold;
      final path = _combinedPath(entry.value);
      final baseBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scaledStroke(size, 1.15)
        ..color = Colors.white.withValues(alpha: 0.20);

      canvas.drawPath(path, baseBorderPaint);

      if (!isControlled) {
        continue;
      }

      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scaledStroke(size, 6.0)
        ..color = color.withValues(alpha: 0.34)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.outer,
          6 / _effectiveZoom,
        );
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scaledStroke(size, 2.1)
        ..color = AppColors.premiumGold.withValues(alpha: 0.92);
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scaledStroke(size, 0.8)
        ..color = Colors.white.withValues(alpha: 0.52);

      canvas.drawPath(path, auraPaint);
      canvas.drawPath(path, borderPaint);
      canvas.drawPath(path, innerPaint);
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
        final liftShadowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.black.withValues(alpha: 0.13);
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = ownerColor.withValues(alpha: 0.66);
        final bevelPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.58)
          ..color = Colors.white.withValues(alpha: 0.16);
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 1.6)
          ..color = ownerColor.withValues(alpha: 0.26);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.86)
          ..color = ownerColor.withValues(alpha: 0.74);
        canvas.save();
        canvas.translate(0.9 / _effectiveZoom, 1.15 / _effectiveZoom);
        for (final path in paths) {
          canvas.drawPath(path, liftShadowPaint);
        }
        canvas.restore();
        for (final path in paths) {
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, bevelPaint);
          canvas.drawPath(path, glowPaint);
          canvas.drawPath(path, edgePaint);
        }
      } else {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF6B7480).withValues(alpha: 0.11);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.7)
          ..color = Colors.white.withValues(alpha: 0.11);
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
        final targetColor = territory.ownerId == state.currentPlayer.id
            ? AppColors.premiumCyan
            : AppColors.premiumRed;
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = targetColor.withValues(alpha: 0.12);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 1.0)
          ..color = targetColor.withValues(alpha: 0.50);
        for (final path in paths) {
          canvas.drawPath(path, paint);
          canvas.drawPath(path, edgePaint);
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
      color: _targetHighlightColor(state.selectedTargetId),
      glowColor: _targetHighlightColor(state.selectedTargetId),
      size: size,
    );
  }

  Color _targetHighlightColor(String? territoryId) {
    final territory = state.territoryByIdOrNull(territoryId);
    if (territory != null && territory.ownerId == state.currentPlayer.id) {
      return AppColors.premiumCyan;
    }
    return AppColors.premiumRed;
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
    final paddingX = (6.2 / zoom).clamp(1.8, 6.8);
    final paddingY = (3.1 / zoom).clamp(1.0, 3.8);
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
      final isNeutral = owner == null;
      final neutralAlpha = zoom < 1.16 && !isActionable ? 0.78 : 1.0;

      final anchor =
          territoryLabelAnchors[territory.id] ??
          Offset(territory.x * size.width, territory.y * size.height);
      final ownerColor = isNeutral
          ? Colors.white.withValues(alpha: 0.52)
          : Color(owner.colorValue);
      final isStrongArmy = territory.armyCount >= 8 && !isNeutral;
      final textPainter = TextPainter(
        text: TextSpan(
          text: territory.armyCount.toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: neutralAlpha),
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
          ..color = ownerColor.withValues(
            alpha: isStrongArmy ? 0.26 * neutralAlpha : 0.14 * neutralAlpha,
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xF2071522).withValues(alpha: neutralAlpha),
              const Color(0xE602080F).withValues(alpha: neutralAlpha),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(0.8 / zoom),
          Radius.circular(4.2 / zoom),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.45 / zoom
          ..color = Colors.white.withValues(alpha: isNeutral ? 0.10 : 0.18),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isStrongArmy ? 1.05 : 0.78) / zoom
          ..color = ownerColor.withValues(
            alpha: isNeutral ? 0.35 : (isStrongArmy ? 0.95 : 0.78),
          ),
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
        !setEquals(oldDelegate.validSourceIds, validSourceIds) ||
        !setEquals(oldDelegate.validTargetIds, validTargetIds) ||
        !setEquals(oldDelegate.controlledContinents, controlledContinents) ||
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
