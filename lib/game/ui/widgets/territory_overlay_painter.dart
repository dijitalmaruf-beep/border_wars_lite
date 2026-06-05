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
    required this.isTransferMode,
    this.mapZoom = 1.0,
    this.victoryOwnerId,
    this.victoryPulse = 0,
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
  final bool isTransferMode;
  final double mapZoom;
  final String? victoryOwnerId;
  final double victoryPulse;
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
      _paintRouteCue(canvas, size);
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
          ..color = Colors.black.withValues(alpha: 0.07);
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = ownerColor.withValues(alpha: 0.90);
        final bevelPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.58)
          ..color = Colors.white.withValues(alpha: 0.22);
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 1.6)
          ..color = ownerColor.withValues(alpha: 0.30);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.86)
          ..color = ownerColor.withValues(alpha: 0.96);
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
          _paintVictoryLift(canvas, path, ownerColor, territory.ownerId);
        }
      } else {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF8EA0A9).withValues(alpha: 0.20);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledStroke(size, 0.7)
          ..color = Colors.white.withValues(alpha: 0.34);
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

  void _paintVictoryLift(
    Canvas canvas,
    Path path,
    Color ownerColor,
    String? ownerId,
  ) {
    if (victoryOwnerId == null || ownerId != victoryOwnerId) {
      return;
    }
    final progress = victoryPulse.clamp(0.0, 1.0).toDouble();
    final wave = 0.5 + math.sin(progress * math.pi * 5) * 0.5;
    final glowAlpha = 0.16 + wave * 0.24;
    final liftAlpha = 0.08 + progress * 0.10;
    canvas.save();
    canvas.translate(1.2 / _effectiveZoom, 1.6 / _effectiveZoom);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black.withValues(alpha: 0.10 + progress * 0.05)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          2.8 / _effectiveZoom,
        ),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = ownerColor.withValues(alpha: liftAlpha)
        ..blendMode = BlendMode.screen,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 / _effectiveZoom
        ..color = ownerColor.withValues(alpha: glowAlpha)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.outer,
          (5.5 + wave * 3.5) / _effectiveZoom,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.95 / _effectiveZoom
        ..color = Colors.white.withValues(alpha: 0.30 + wave * 0.24),
    );
  }

  void _paintHighlights(Canvas canvas, Size size) {
    _paintHighlight(
      canvas,
      state.selectedSourceId,
      color: isTransferMode ? const Color(0xFF27E0CF) : const Color(0xFF2A91FF),
      glowColor: isTransferMode
          ? const Color(0xFF00F5D4)
          : const Color(0xFF00A8FF),
      size: size,
      isSource: true,
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
    bool isSource = false,
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
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 1.2)
      ..color = color.withValues(alpha: 0.78)
      ..strokeCap = StrokeCap.round;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / _effectiveZoom
      ..color = Colors.white.withValues(alpha: 0.82);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
    canvas.drawPath(path, innerPaint);
    if (isSource && isTransferMode) {
      _drawDashedPath(canvas, path, dashPaint, dash: 7, gap: 5);
    }
  }

  void _paintRouteCue(Canvas canvas, Size size) {
    final sourceId = state.selectedSourceId;
    final targetId = state.selectedTargetId;
    if (sourceId == null || targetId == null) {
      return;
    }
    final source = state.territoryByIdOrNull(sourceId);
    final target = state.territoryByIdOrNull(targetId);
    final start = territoryLabelAnchors[sourceId];
    final end = territoryLabelAnchors[targetId];
    if (source == null || target == null || start == null || end == null) {
      return;
    }
    final isTransferRoute =
        isTransferMode && target.ownerId == state.currentPlayer.id;
    final color = isTransferRoute
        ? AppColors.premiumCyan
        : const Color(0xFFFF4E5E);
    final glowColor = isTransferRoute
        ? const Color(0xFF19F0D0)
        : const Color(0xFFFF9C4A);
    final route = _curvedRoute(start, end);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 7.0)
      ..strokeCap = StrokeCap.round
      ..color = glowColor.withValues(alpha: 0.30)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        5 / _effectiveZoom,
      );
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 2.2)
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(start, end, <Color>[
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.95),
      ]);
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _scaledStroke(size, 1.25)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.58);

    canvas.drawPath(route, glowPaint);
    canvas.drawPath(route, routePaint);
    _drawDashedPath(canvas, route, dashPaint, dash: 10, gap: 7);
    _drawArrowHead(canvas, start, end, color);
    _drawRouteBadge(canvas, (start + end) / 2, color, isTransferRoute);
  }

  Path _curvedRoute(Offset start, Offset end) {
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx);
    final bendDistance = (delta.distance * 0.18).clamp(10.0, 30.0);
    final control =
        (start + end) / 2 +
        (normal.distance == 0
            ? Offset.zero
            : normal / normal.distance * bendDistance);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Color color) {
    final direction = end - start;
    if (direction.distance < 4) {
      return;
    }
    final unit = direction / direction.distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final tip = end - unit * (14 / _effectiveZoom);
    final back = tip - unit * (11 / _effectiveZoom);
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (back + perpendicular * (6 / _effectiveZoom)).dx,
        (back + perpendicular * (6 / _effectiveZoom)).dy,
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (back - perpendicular * (6 / _effectiveZoom)).dx,
        (back - perpendicular * (6 / _effectiveZoom)).dy,
      );
    canvas.drawPath(
      arrowPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1 / _effectiveZoom
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.95),
    );
  }

  void _drawRouteBadge(
    Canvas canvas,
    Offset center,
    Color color,
    bool isTransferRoute,
  ) {
    final radius = 11 / _effectiveZoom;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.36),
            const Color(0xF005111A),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / _effectiveZoom
        ..color = color.withValues(alpha: 0.95),
    );

    if (isTransferRoute) {
      _drawTransferIcon(canvas, center, color);
    } else {
      _drawSwordIcon(canvas, center, color);
    }
  }

  void _drawTransferIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / _effectiveZoom
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.92);
    final scale = 1 / _effectiveZoom;
    final left = center + Offset(-6 * scale, -2.5 * scale);
    final right = center + Offset(6 * scale, -2.5 * scale);
    canvas.drawLine(left, right, paint);
    canvas.drawLine(right, right + Offset(-3.8 * scale, -3.2 * scale), paint);
    canvas.drawLine(right, right + Offset(-3.8 * scale, 3.2 * scale), paint);

    final lowerLeft = center + Offset(-6 * scale, 3.5 * scale);
    final lowerRight = center + Offset(6 * scale, 3.5 * scale);
    canvas.drawLine(lowerRight, lowerLeft, paint);
    canvas.drawLine(
      lowerLeft,
      lowerLeft + Offset(3.8 * scale, -3.2 * scale),
      paint,
    );
    canvas.drawLine(
      lowerLeft,
      lowerLeft + Offset(3.8 * scale, 3.2 * scale),
      paint,
    );
    canvas.drawCircle(
      center,
      2.1 * scale,
      Paint()..color = color.withValues(alpha: 0.75),
    );
  }

  void _drawSwordIcon(Canvas canvas, Offset center, Color color) {
    final scale = 1 / _effectiveZoom;
    final bladePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.95);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.95);
    final start = center + Offset(-5.5 * scale, 5.5 * scale);
    final end = center + Offset(5.5 * scale, -5.5 * scale);
    canvas.drawLine(start, end, bladePaint);
    final guardCenter = center + Offset(-2.4 * scale, 2.4 * scale);
    canvas.drawLine(
      guardCenter + Offset(-3.2 * scale, -1.1 * scale),
      guardCenter + Offset(1.1 * scale, 3.2 * scale),
      accentPaint,
    );
    canvas.drawLine(
      center + Offset(-6.4 * scale, 6.4 * scale),
      center + Offset(-3.9 * scale, 3.9 * scale),
      accentPaint,
    );
  }

  void _paintArmyLabels(Canvas canvas, Size size) {
    final zoom = _effectiveZoom;
    final visualFontSize = (10.0 - (zoom - 1) * 1.08).clamp(7.1, 10.2);
    final digitHeight = (visualFontSize + 0.6) / zoom;
    final paddingX = (6.8 / zoom).clamp(2.1, 7.2);
    final paddingY = (3.9 / zoom).clamp(1.2, 4.2);
    final minChipWidth = 19.5 / zoom;
    final minChipHeight = 15.5 / zoom;
    final radius = Radius.circular(5.6 / zoom);
    final placedRects = <Rect>[];

    for (final territory in state.territories) {
      final owner = state.playerById(territory.ownerId);
      final isNeutral = owner == null;

      final anchor =
          territoryLabelAnchors[territory.id] ??
          Offset(territory.x * size.width, territory.y * size.height);
      final ownerColor = isNeutral
          ? const Color(0xFFD7E8F4)
          : Color(owner.colorValue);
      final isStrongArmy = territory.armyCount >= 8 && !isNeutral;
      final label = territory.armyCount.toString();
      final numberSize = _armyNumberSize(label, digitHeight);

      final chipWidth = math.max(
        minChipWidth,
        numberSize.width + paddingX * 2,
      );
      final chipHeight = math.max(
        minChipHeight,
        numberSize.height + paddingY * 2,
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
        RRect.fromRectAndRadius(
          rect.shift(Offset(0, 1.4 / zoom)),
          Radius.circular(5.4 / zoom),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            2.6 / zoom,
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(0.7 / zoom), radius),
        Paint()
          ..color = ownerColor.withValues(
            alpha: isNeutral ? 0.12 : (isStrongArmy ? 0.30 : 0.22),
          )
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            1.2 / zoom,
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
              const Color(0xF40D2636),
              const Color(0xF207151F),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.fill
          ..color = ownerColor.withValues(
            alpha: isNeutral ? 0.06 : (isStrongArmy ? 0.18 : 0.12),
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5 / zoom), radius),
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.16),
              Colors.transparent,
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
          ..strokeWidth = 0.60 / zoom
          ..color = Colors.white.withValues(alpha: 0.58),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isStrongArmy ? 1.10 : 0.86) / zoom
          ..color = ownerColor.withValues(
            alpha: isNeutral ? 0.74 : (isStrongArmy ? 1.0 : 0.96),
          ),
      );

      _paintArmyNumber(
        canvas,
        center,
        label,
        digitHeight,
        zoom,
      );
    }
  }

  Size _armyNumberSize(String label, double digitHeight) {
    final digitWidth = digitHeight * 0.56;
    final gap = digitHeight * 0.18;
    final width =
        label.length * digitWidth + math.max(0, label.length - 1) * gap;
    return Size(width, digitHeight);
  }

  void _paintArmyNumber(
    Canvas canvas,
    Offset center,
    String label,
    double digitHeight,
    double zoom,
  ) {
    final numberSize = _armyNumberSize(label, digitHeight);
    final digitWidth = digitHeight * 0.56;
    final gap = digitHeight * 0.18;
    final strokeWidth = (1.78 / zoom).clamp(0.72, 1.95).toDouble();
    final startX = center.dx - numberSize.width / 2;
    final top = center.dy - numberSize.height / 2;
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth + 0.95 / zoom
      ..color = const Color(0xE6000208);
    final numberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFFFFFFF);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth + 0.70 / zoom
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.0 / zoom);

    for (var index = 0; index < label.length; index += 1) {
      final char = label[index];
      final left = startX + index * (digitWidth + gap);
      final digitRect = Rect.fromLTWH(left, top, digitWidth, digitHeight);
      _paintSegmentDigit(
        canvas,
        digitRect.shift(Offset(0, 0.55 / zoom)),
        char,
        shadowPaint,
      );
      _paintSegmentDigit(canvas, digitRect, char, glowPaint);
      _paintSegmentDigit(canvas, digitRect, char, numberPaint);
    }
  }

  void _paintSegmentDigit(
    Canvas canvas,
    Rect rect,
    String digit,
    Paint paint,
  ) {
    final segments = _digitSegments(digit);
    if (segments.isEmpty) {
      return;
    }
    final insetX = rect.width * 0.11;
    final insetY = rect.height * 0.09;
    final left = rect.left + insetX;
    final right = rect.right - insetX;
    final top = rect.top + insetY;
    final middle = rect.center.dy;
    final bottom = rect.bottom - insetY;
    final upperY = rect.top + rect.height * 0.30;
    final lowerY = rect.top + rect.height * 0.70;

    void line(Offset a, Offset b) {
      canvas.drawLine(a, b, paint);
    }

    if (segments.contains('a')) {
      line(Offset(left, top), Offset(right, top));
    }
    if (segments.contains('b')) {
      line(Offset(right, top), Offset(right, middle));
    }
    if (segments.contains('c')) {
      line(Offset(right, middle), Offset(right, bottom));
    }
    if (segments.contains('d')) {
      line(Offset(left, bottom), Offset(right, bottom));
    }
    if (segments.contains('e')) {
      line(Offset(left, middle), Offset(left, bottom));
    }
    if (segments.contains('f')) {
      line(Offset(left, top), Offset(left, middle));
    }
    if (segments.contains('g')) {
      line(Offset(left, middle), Offset(right, middle));
    }
    if (segments.contains('h')) {
      line(Offset(left, upperY), Offset(right, lowerY));
    }
  }

  Set<String> _digitSegments(String digit) {
    switch (digit) {
      case '0':
        return const <String>{'a', 'b', 'c', 'd', 'e', 'f'};
      case '1':
        return const <String>{'b', 'c'};
      case '2':
        return const <String>{'a', 'b', 'g', 'e', 'd'};
      case '3':
        return const <String>{'a', 'b', 'g', 'c', 'd'};
      case '4':
        return const <String>{'f', 'g', 'b', 'c'};
      case '5':
        return const <String>{'a', 'f', 'g', 'c', 'd'};
      case '6':
        return const <String>{'a', 'f', 'g', 'e', 'c', 'd'};
      case '7':
        return const <String>{'a', 'b', 'c'};
      case '8':
        return const <String>{'a', 'b', 'c', 'd', 'e', 'f', 'g'};
      case '9':
        return const <String>{'a', 'b', 'c', 'd', 'f', 'g'};
      default:
        return const <String>{};
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
        oldDelegate.isTransferMode != isTransferMode ||
        oldDelegate.mapZoom != mapZoom ||
        oldDelegate.victoryOwnerId != victoryOwnerId ||
        (oldDelegate.victoryPulse - victoryPulse).abs() > 0.01 ||
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

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final scaledDash = dash / _effectiveZoom;
    final scaledGap = gap / _effectiveZoom;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + scaledDash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + scaledGap;
      }
    }
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
