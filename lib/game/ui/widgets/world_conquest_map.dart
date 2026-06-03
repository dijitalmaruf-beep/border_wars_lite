import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/game_state.dart';
import '../../models/territory.dart';
import 'territory_overlay_painter.dart';

class WorldConquestMap extends StatefulWidget {
  const WorldConquestMap({
    required this.state,
    required this.validSourceIds,
    required this.validTargetIds,
    required this.controlledContinents,
    required this.isTransferMode,
    required this.onTerritoryTap,
    this.pulseTerritoryId,
    this.pulseLabel,
    this.pulseColor,
    this.pulseSerial = 0,
    super.key,
  });

  final GameState state;
  final Set<String> validSourceIds;
  final Set<String> validTargetIds;
  final Set<String> controlledContinents;
  final bool isTransferMode;
  final ValueChanged<String> onTerritoryTap;
  final String? pulseTerritoryId;
  final String? pulseLabel;
  final Color? pulseColor;
  final int pulseSerial;

  @override
  State<WorldConquestMap> createState() => _WorldConquestMapState();
}

class _WorldConquestMapState extends State<WorldConquestMap> {
  static const _mapAspectRatio = 2.0;
  static const _baseMapAsset = 'assets/maps/world_base.png';
  static const _borderMapAsset = 'assets/maps/world_borders.svg';
  static const _portraitOpeningCenterX = 0.54;
  static const _portraitOpeningCenterY = 0.40;
  static const _portraitMapZoom = 1.16;
  static const _zoomPaintStep = 0.20;
  static const _labelAnchorOverrides = <String, Offset>{
    'western_canada': Offset(0.173, 0.176),
    'eastern_canada': Offset(0.305, 0.190),
    'western_us': Offset(0.176, 0.282),
    'central_us': Offset(0.238, 0.286),
    'eastern_us': Offset(0.292, 0.286),
    'mexico': Offset(0.214, 0.360),
    'central_america': Offset(0.248, 0.420),
    'caribbean': Offset(0.316, 0.402),
    'andes': Offset(0.295, 0.555),
    'brazil': Offset(0.385, 0.575),
    'southern_cone': Offset(0.330, 0.666),
    'patagonia': Offset(0.322, 0.755),
    'western_europe': Offset(0.496, 0.250),
    'central_europe': Offset(0.535, 0.225),
    'balkans': Offset(0.565, 0.275),
    'scandinavia': Offset(0.545, 0.155),
    'eastern_europe': Offset(0.596, 0.220),
    'north_africa': Offset(0.525, 0.363),
    'west_africa': Offset(0.475, 0.445),
    'central_africa': Offset(0.535, 0.520),
    'east_africa': Offset(0.600, 0.495),
    'southern_africa': Offset(0.548, 0.655),
    'madagascar': Offset(0.632, 0.610),
    'middle_east': Offset(0.604, 0.328),
    'arabia': Offset(0.635, 0.385),
    'central_asia': Offset(0.688, 0.250),
    'india': Offset(0.717, 0.378),
    'southeast_asia': Offset(0.781, 0.425),
    'china_north': Offset(0.775, 0.305),
    'china_south': Offset(0.790, 0.375),
    'siberia': Offset(0.750, 0.150),
    'far_east_russia': Offset(0.875, 0.180),
    'korea_japan': Offset(0.875, 0.292),
    'indonesia': Offset(0.825, 0.515),
    'new_guinea': Offset(0.902, 0.535),
    'australia_west': Offset(0.840, 0.642),
    'australia_east': Offset(0.908, 0.650),
  };

  final TransformationController _transformationController =
      TransformationController();

  Size? _cachedSize;
  Size? _lastMapSize;
  Size? _lastViewportSize;
  double _mapZoom = 1.0;
  double _globeRotation = 0.0;
  Map<String, List<Path>> _cachedPaths = const <String, List<Path>>{};
  Map<String, Path> _cachedHighlightPaths = const <String, Path>{};
  Map<String, Offset> _cachedLabelAnchors = const <String, Offset>{};

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final nextZoom = _quantizedZoom(_currentMapZoom());
    final nextRotation = _currentGlobeRotation();
    if ((nextZoom - _mapZoom).abs() < 0.01 &&
        (nextRotation - _globeRotation).abs() < 0.018) {
      return;
    }
    if (!mounted) {
      _mapZoom = nextZoom;
      _globeRotation = nextRotation;
      return;
    }
    setState(() {
      _mapZoom = nextZoom;
      _globeRotation = nextRotation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final mapSize = _coveringMapSize(viewportSize);
        final paths = _pathsFor(mapSize);
        final highlightPaths = _highlightPathsFor(mapSize);
        final labelAnchors = _labelAnchorsFor(mapSize, paths);
        _syncInitialView(viewportSize, mapSize);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const RepaintBoundary(
              child: CustomPaint(painter: _GlobeBackdropPainter()),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: const _GlobeViewportClipper(),
                clipBehavior: Clip.antiAlias,
                child: Transform(
                  alignment: Alignment.center,
                  transform: _globePerspectiveTransform(),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.75,
                    maxScale: 4,
                    constrained: false,
                    clipBehavior: Clip.none,
                    boundaryMargin: const EdgeInsets.all(24),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final territoryId = _territoryAt(
                          details.localPosition,
                          paths,
                        );
                        if (territoryId != null) {
                          widget.onTerritoryTap(territoryId);
                        }
                      },
                      child: SizedBox(
                        width: mapSize.width,
                        height: mapSize.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            RepaintBoundary(
                              child: Image.asset(
                                _baseMapAsset,
                                fit: BoxFit.fill,
                              ),
                            ),
                            const RepaintBoundary(
                              child: CustomPaint(painter: _MapDepthPainter()),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _MapReliefPainter(
                                  territoryPaths: paths,
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: TerritoryOverlayPainter(
                                  state: widget.state,
                                  territoryPaths: paths,
                                  territoryHighlightPaths: highlightPaths,
                                  territoryLabelAnchors: labelAnchors,
                                  validSourceIds: widget.validSourceIds,
                                  validTargetIds: widget.validTargetIds,
                                  controlledContinents:
                                      widget.controlledContinents,
                                  isTransferMode: widget.isTransferMode,
                                  mapZoom: 1.0,
                                  paintOwnership: true,
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: SvgPicture.asset(
                                _borderMapAsset,
                                fit: BoxFit.fill,
                                allowDrawingOutsideViewBox: false,
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: TerritoryOverlayPainter(
                                  state: widget.state,
                                  territoryPaths: paths,
                                  territoryHighlightPaths: highlightPaths,
                                  territoryLabelAnchors: labelAnchors,
                                  validSourceIds: widget.validSourceIds,
                                  validTargetIds: widget.validTargetIds,
                                  controlledContinents:
                                      widget.controlledContinents,
                                  isTransferMode: widget.isTransferMode,
                                  mapZoom: _mapZoom,
                                  paintLabelsAndHighlights: true,
                                ),
                              ),
                            ),
                            if (widget.pulseTerritoryId != null &&
                                widget.pulseLabel != null &&
                                widget.pulseColor != null &&
                                labelAnchors.containsKey(
                                  widget.pulseTerritoryId,
                                ))
                              Positioned(
                                key: ValueKey<int>(widget.pulseSerial),
                                left: labelAnchors[widget.pulseTerritoryId]!.dx,
                                top: labelAnchors[widget.pulseTerritoryId]!.dy,
                                child: IgnorePointer(
                                  child: _MapPulseOverlay(
                                    label: widget.pulseLabel!,
                                    color: widget.pulseColor!,
                                    inverseScale: 1 / _mapZoom.clamp(0.75, 4.0),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GlobeViewportFramePainter(
                      rotation: _globeRotation,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<Path>> _pathsFor(Size size) {
    if (_cachedSize == size && _cachedPaths.isNotEmpty) {
      return _cachedPaths;
    }

    _cachedSize = size;
    _cachedPaths = <String, List<Path>>{
      for (final territory in widget.state.territories)
        territory.id: _pathsForTerritory(territory, size),
    };
    _cachedHighlightPaths = const <String, Path>{};
    _cachedLabelAnchors = const <String, Offset>{};
    return _cachedPaths;
  }

  Map<String, Path> _highlightPathsFor(Size size) {
    if (_cachedSize == size && _cachedHighlightPaths.isNotEmpty) {
      return _cachedHighlightPaths;
    }

    _cachedHighlightPaths = <String, Path>{
      for (final territory in widget.state.territories)
        territory.id: _highlightPathForTerritory(territory, size),
    };
    return _cachedHighlightPaths;
  }

  Map<String, Offset> _labelAnchorsFor(
    Size size,
    Map<String, List<Path>> paths,
  ) {
    if (_cachedSize == size && _cachedLabelAnchors.isNotEmpty) {
      return _cachedLabelAnchors;
    }

    _cachedLabelAnchors = <String, Offset>{
      for (final territory in widget.state.territories)
        territory.id: _labelAnchorForTerritory(
          territory,
          paths[territory.id] ?? const <Path>[],
          size,
        ),
    };
    return _cachedLabelAnchors;
  }

  List<Path> _pathsForTerritory(Territory territory, Size size) {
    final boundaries = territory.visualBoundaries;
    if (boundaries.isEmpty) {
      final center = Offset(
        territory.x * size.width,
        territory.y * size.height,
      );
      return <Path>[
        Path()..addRect(Rect.fromCenter(center: center, width: 8, height: 8)),
      ];
    }

    return <Path>[
      for (final boundary in boundaries)
        if (boundary.length >= 3) _pathForBoundary(boundary, size),
    ];
  }

  Path _pathForBoundary(List<MapPoint> boundary, Size size) {
    final path = Path();
    path.moveTo(boundary.first.x * size.width, boundary.first.y * size.height);
    for (final point in boundary.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    path.close();
    return path;
  }

  Path _highlightPathForTerritory(Territory territory, Size size) {
    final paths = _pathsForTerritory(territory, size);
    if (paths.isEmpty) {
      return Path();
    }
    if (paths.length == 1) {
      return paths.first;
    }

    final anchor = Offset(territory.x * size.width, territory.y * size.height);
    final areas = <Path, double>{
      for (final path in paths) path: _pathBoundsArea(path),
    };
    final maxArea = areas.values.fold<double>(0, math.max);
    final filtered = <Path>[
      for (final path in paths)
        if ((areas[path] ?? 0) >= maxArea * 0.10 || path.contains(anchor)) path,
    ];
    final highlightParts = filtered.isEmpty ? <Path>[paths.first] : filtered;
    return _combinedPath(highlightParts);
  }

  String? _territoryAt(Offset position, Map<String, List<Path>> paths) {
    for (final territory in widget.state.territories.reversed) {
      final territoryPaths = paths[territory.id] ?? const <Path>[];
      if (territoryPaths.any((path) => path.contains(position))) {
        return territory.id;
      }
    }
    return null;
  }

  Offset _labelAnchorForTerritory(
    Territory territory,
    List<Path> paths,
    Size size,
  ) {
    final override = _labelAnchorOverrides[territory.id];
    final desired = override == null
        ? Offset(territory.x * size.width, territory.y * size.height)
        : Offset(override.dx * size.width, override.dy * size.height);
    for (final path in paths) {
      if (path.contains(desired)) {
        return desired;
      }
    }

    final bestPath = _bestPathForLabel(paths, desired);
    if (bestPath == null) {
      return desired;
    }

    final bounds = bestPath.getBounds();
    final center = bounds.center;
    if (bestPath.contains(center)) {
      return center;
    }

    final candidates = <Offset>[
      center,
      Offset(
        bounds.left + bounds.width * 0.45,
        bounds.top + bounds.height * 0.50,
      ),
      Offset(
        bounds.left + bounds.width * 0.55,
        bounds.top + bounds.height * 0.50,
      ),
      Offset(
        bounds.left + bounds.width * 0.50,
        bounds.top + bounds.height * 0.42,
      ),
      Offset(
        bounds.left + bounds.width * 0.50,
        bounds.top + bounds.height * 0.58,
      ),
      Offset(
        bounds.left + bounds.width * 0.38,
        bounds.top + bounds.height * 0.46,
      ),
      Offset(
        bounds.left + bounds.width * 0.62,
        bounds.top + bounds.height * 0.54,
      ),
      desired,
    ];

    for (final candidate in candidates) {
      if (bestPath.contains(candidate)) {
        return candidate;
      }
    }

    return center;
  }

  Path? _bestPathForLabel(List<Path> paths, Offset desired) {
    if (paths.isEmpty) {
      return null;
    }

    Path? bestPath;
    var bestScore = double.infinity;
    for (final path in paths) {
      final bounds = path.getBounds();
      if (bounds.isEmpty) {
        continue;
      }
      final area = bounds.width * bounds.height;
      final distance = (bounds.center - desired).distance;
      final score = distance - math.sqrt(area) * 0.18;
      if (score < bestScore) {
        bestScore = score;
        bestPath = path;
      }
    }
    return bestPath ?? paths.first;
  }

  Size _coveringMapSize(Size viewportSize) {
    final mapHeight = math.max(
      viewportSize.height * _portraitMapZoom,
      viewportSize.width / _mapAspectRatio,
    );
    return Size(mapHeight * _mapAspectRatio, mapHeight);
  }

  double _currentMapZoom() {
    return _transformationController.value
        .getMaxScaleOnAxis()
        .clamp(0.75, 4.0)
        .toDouble();
  }

  double _currentGlobeRotation() {
    final viewportSize = _lastViewportSize;
    final mapSize = _lastMapSize;
    if (viewportSize == null || mapSize == null || mapSize.width <= 0) {
      return _globeRotation;
    }
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis().clamp(0.75, 4.0).toDouble();
    final translation = matrix.getTranslation();
    final centerX = (viewportSize.width / 2 - translation.x) / scale;
    final normalizedCenterX = (centerX / mapSize.width).clamp(0.0, 1.0);
    return normalizedCenterX * math.pi * 2;
  }

  Matrix4 _globePerspectiveTransform() {
    final yaw = math.sin(_globeRotation) * 0.105;
    final lift = math.cos(_globeRotation) * 0.012;
    return Matrix4.identity()
      ..setEntry(3, 2, 0.00075)
      ..rotateY(yaw)
      ..rotateX(lift)
      ..scaleByDouble(1.015, 1.01, 1, 1);
  }

  double _quantizedZoom(double zoom) {
    final clamped = zoom.clamp(0.75, 4.0).toDouble();
    return (clamped / _zoomPaintStep).round() * _zoomPaintStep;
  }

  void _syncInitialView(Size viewportSize, Size mapSize) {
    if (_lastViewportSize == viewportSize && _lastMapSize == mapSize) {
      return;
    }

    final previousViewportSize = _lastViewportSize;
    final previousMapSize = _lastMapSize;
    if (previousViewportSize != null && previousMapSize != null) {
      final matrix = _transformationController.value;
      final scale = matrix.getMaxScaleOnAxis().clamp(0.75, 4.0).toDouble();
      final translation = matrix.getTranslation();
      final previousCenter = Offset(
        (previousViewportSize.width / 2 - translation.x) / scale,
        (previousViewportSize.height / 2 - translation.y) / scale,
      );
      final normalizedCenter = Offset(
        (previousCenter.dx / previousMapSize.width).clamp(0.0, 1.0),
        (previousCenter.dy / previousMapSize.height).clamp(0.0, 1.0),
      );
      final nextCenter = Offset(
        normalizedCenter.dx * mapSize.width,
        normalizedCenter.dy * mapSize.height,
      );

      _lastViewportSize = viewportSize;
      _lastMapSize = mapSize;
      _mapZoom = _quantizedZoom(scale);
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(
          viewportSize.width / 2 - nextCenter.dx * scale,
          viewportSize.height / 2 - nextCenter.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
      _globeRotation = _currentGlobeRotation();
      return;
    }

    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    final dx = mapSize.width <= viewportSize.width + 0.5
        ? (viewportSize.width - mapSize.width) / 2
        : viewportSize.width / 2 - mapSize.width * _portraitOpeningCenterX;
    final rawDy = mapSize.height <= viewportSize.height + 0.5
        ? (viewportSize.height - mapSize.height) / 2
        : viewportSize.height / 2 - mapSize.height * _portraitOpeningCenterY;
    final dy = mapSize.height <= viewportSize.height + 0.5
        ? rawDy
        : math.min(0.0, rawDy);
    _mapZoom = 1.0;
    _transformationController.value = Matrix4.translationValues(dx, dy, 0);
    _globeRotation = _currentGlobeRotation();
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

  double _pathBoundsArea(Path path) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) {
      return 0;
    }
    return bounds.width * bounds.height;
  }
}

class _MapPulseOverlay extends StatelessWidget {
  const _MapPulseOverlay({
    required this.label,
    required this.color,
    required this.inverseScale,
  });

  final String label;
  final Color color;
  final double inverseScale;

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: const Offset(-0.5, -1.35),
      child: Transform.scale(
        scale: inverseScale,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 2300),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            final opacity = value < 0.84 ? 1.0 : (1 - value) / 0.16;
            return Opacity(
              opacity: opacity.clamp(0, 1).toDouble(),
              child: Transform.translate(
                offset: Offset(0, -10 * value),
                child: Transform.scale(
                  scale: 0.98 + 0.06 * value,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  color.withValues(alpha: 0.92),
                  const Color(0xF4051019),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.62), blurRadius: 18),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.44),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobeViewportClipper extends CustomClipper<Path> {
  const _GlobeViewportClipper();

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(
      -size.width * 0.035,
      -size.height * 0.105,
      size.width * 1.07,
      size.height * 1.22,
    );
    return Path()..addOval(rect);
  }

  @override
  bool shouldReclip(covariant _GlobeViewportClipper oldClipper) => false;
}

class _GlobeBackdropPainter extends CustomPainter {
  const _GlobeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF031521),
            Color(0xFF020812),
            Color(0xFF000309),
          ],
        ).createShader(rect),
    );

    final glowRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.48),
      width: size.width * 1.12,
      height: size.height * 1.18,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(20, size.width * 0.045)
        ..color = const Color(0xFF0B9FD2).withValues(alpha: 0.13)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 28),
    );
  }

  @override
  bool shouldRepaint(covariant _GlobeBackdropPainter oldDelegate) => false;
}

class _GlobeViewportFramePainter extends CustomPainter {
  const _GlobeViewportFramePainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final globeRect = Rect.fromLTWH(
      -size.width * 0.035,
      -size.height * 0.105,
      size.width * 1.07,
      size.height * 1.22,
    );
    final globePath = Path()..addOval(globeRect);
    final outsidePath = Path.combine(
      ui.PathOperation.difference,
      Path()..addRect(rect),
      globePath,
    );

    canvas.drawPath(
      outsidePath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.86,
          colors: <Color>[
            const Color(0xFF020B14).withValues(alpha: 0.34),
            const Color(0xFF00040A).withValues(alpha: 0.92),
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(globePath);
    _paintRotatingMeridians(canvas, size, globeRect);
    _paintHemisphereShade(canvas, size);
    canvas.restore();

    canvas.drawOval(
      globeRect.inflate(size.width * 0.006),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(7, size.width * 0.010)
        ..color = const Color(0xFF31D9FF).withValues(alpha: 0.18)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );
    canvas.drawOval(
      globeRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, size.width * 0.0015)
        ..color = const Color(0xFFC8F7FF).withValues(alpha: 0.42),
    );
    canvas.drawOval(
      globeRect.deflate(size.width * 0.010),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, size.width * 0.0009)
        ..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  void _paintRotatingMeridians(Canvas canvas, Size size, Rect globeRect) {
    final center = globeRect.center;
    final meridianPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, size.width * 0.00055)
      ..color = const Color(0xFFC7F8FF).withValues(alpha: 0.105);
    final brightMeridianPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, size.width * 0.00080)
      ..color = const Color(0xFF71EDFF).withValues(alpha: 0.16);

    final phase = (rotation / (math.pi * 2)) % 1.0;
    for (var index = -4; index <= 4; index += 1) {
      var shifted = ((index / 4) + phase + 1.5) % 2.0 - 1.0;
      shifted = shifted.clamp(-0.98, 0.98).toDouble();
      final proximity = 1 - shifted.abs();
      final width = globeRect.width * (0.10 + proximity * 0.42);
      final meridianRect = Rect.fromCenter(
        center: Offset(center.dx + shifted * globeRect.width * 0.36, center.dy),
        width: width,
        height: globeRect.height * 1.01,
      );
      canvas.drawOval(
        meridianRect,
        proximity > 0.82 ? brightMeridianPaint : meridianPaint,
      );
    }

    final latitudePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, size.width * 0.00052)
      ..color = const Color(0xFFB8F5FF).withValues(alpha: 0.075);
    for (final offset in const <double>[-0.34, -0.18, 0.0, 0.18, 0.34]) {
      final y = center.dy + globeRect.height * offset;
      final latitudeRect = Rect.fromCenter(
        center: Offset(center.dx, y),
        width: globeRect.width * (0.88 - offset.abs() * 0.76),
        height: globeRect.height * 0.12,
      );
      canvas.drawOval(latitudeRect, latitudePaint);
    }
  }

  void _paintHemisphereShade(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.36, -0.36),
          radius: 0.74,
          colors: <Color>[const Color(0x2E9CF8FF), Colors.transparent],
          stops: const <double>[0.0, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.screen,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.84, 0.78),
          radius: 0.92,
          colors: <Color>[Colors.transparent, const Color(0xB9000207)],
          stops: const <double>[0.38, 1.0],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0x7A00040A),
            Color(0x0000040A),
            Color(0x6300040A),
          ],
          stops: <double>[0.0, 0.48, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GlobeViewportFramePainter oldDelegate) {
    return (oldDelegate.rotation - rotation).abs() > 0.001;
  }
}

class _MapDepthPainter extends CustomPainter {
  const _MapDepthPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final oceanWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0x220FD9FF),
          const Color(0x08001222),
          const Color(0x3A00040E),
        ],
        stops: const <double>[0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, oceanWash);

    final specularLight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.34),
        radius: 0.58,
        colors: <Color>[
          const Color(0x4A9EF7FF),
          const Color(0x1CF3D18A),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.screen;
    canvas.drawRect(rect, specularLight);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.42, size.width * 0.00022)
      ..color = Colors.white.withValues(alpha: 0.040);
    const divisions = 10;
    for (var i = 1; i < divisions; i++) {
      final t = i / divisions;
      final x = size.width * t;
      final bend = (t - 0.5) * size.height * 0.10;
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(
          x - bend,
          size.height * 0.28,
          x + bend,
          size.height * 0.72,
          x,
          size.height,
        );
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final t = i / 5;
      final y = size.height * t;
      final curve = (t - 0.5) * size.height * 0.11;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.5, y + curve, size.width, y);
      canvas.drawPath(path, gridPaint);
    }

    final rimRect = Rect.fromLTWH(
      -size.width * 0.075,
      -size.height * 0.335,
      size.width * 1.15,
      size.height * 1.62,
    );
    final rimGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(8, size.width * 0.006)
      ..color = const Color(0xFF45D9FF).withValues(alpha: 0.12)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    final rimLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.00072)
      ..color = const Color(0xFFB4F4FF).withValues(alpha: 0.30);
    canvas.drawOval(rimRect, rimGlow);
    canvas.drawOval(rimRect, rimLine);

    final terminator = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.72, 0.76),
        radius: 0.95,
        colors: <Color>[Colors.transparent, const Color(0xB8000308)],
        stops: const <double>[0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, terminator);

    final edgeVignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.10, -0.08),
        radius: 0.94,
        colors: <Color>[Colors.transparent, const Color(0x8A000612)],
        stops: const <double>[0.64, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, edgeVignette);
  }

  @override
  bool shouldRepaint(covariant _MapDepthPainter oldDelegate) => false;
}

class _MapReliefPainter extends CustomPainter {
  const _MapReliefPainter({required this.territoryPaths});

  final Map<String, List<Path>> territoryPaths;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.13);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, size.width * 0.00035)
      ..color = Colors.white.withValues(alpha: 0.10);
    final lowRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, size.width * 0.00042)
      ..color = const Color(0xFF001622).withValues(alpha: 0.22);

    final paths = territoryPaths.values.expand((paths) => paths);
    canvas.save();
    canvas.translate(1.4, 1.8);
    for (final path in paths) {
      canvas.drawPath(path, shadowPaint);
    }
    canvas.restore();

    for (final path in territoryPaths.values.expand((paths) => paths)) {
      canvas.drawPath(path, lowRimPaint);
      canvas.drawPath(path, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapReliefPainter oldDelegate) {
    return oldDelegate.territoryPaths != territoryPaths;
  }
}
