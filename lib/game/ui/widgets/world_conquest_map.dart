import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/game_state.dart';
import '../../models/territory.dart';
import 'territory_overlay_painter.dart';

class WorldConquestMap extends StatefulWidget {
  const WorldConquestMap({
    required this.state,
    required this.validTargetIds,
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
  final Set<String> validTargetIds;
  final ValueChanged<String> onTerritoryTap;

  @override
  State<WorldConquestMap> createState() => _WorldConquestMapState();
}

class _WorldConquestMapState extends State<WorldConquestMap> {
  static const _mapAspectRatio = 2.0;
  static const _baseMapAsset = 'assets/maps/world_base.png';
  static const _borderMapAsset = 'assets/maps/world_borders.svg';
  static const _portraitOpeningCenterX = 0.56;
  static const _portraitOpeningCenterY = 0.46;
  static const _portraitMapZoom = 1.22;

  final TransformationController _transformationController =
      TransformationController();

  Size? _cachedSize;
  Size? _lastMapSize;
  Size? _lastViewportSize;
  Map<String, List<Path>> _cachedPaths = const <String, List<Path>>{};
  Map<String, Path> _cachedHighlightPaths = const <String, Path>{};
  Map<String, Offset> _cachedLabelAnchors = const <String, Offset>{};

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
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

        return AnimatedBuilder(
          animation: _transformationController,
          builder: (context, _) {
            final mapZoom = _currentMapZoom();
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.75,
              maxScale: 4,
              constrained: false,
              clipBehavior: Clip.hardEdge,
              boundaryMargin: const EdgeInsets.all(24),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
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
                      Image.asset(_baseMapAsset, fit: BoxFit.fill),
                      CustomPaint(
                        painter: TerritoryOverlayPainter(
                          state: widget.state,
                          territoryPaths: paths,
                          territoryHighlightPaths: highlightPaths,
                          territoryLabelAnchors: labelAnchors,
                          validTargetIds: widget.validTargetIds,
                          mapZoom: mapZoom,
                          paintOwnership: true,
                        ),
                      ),
                      SvgPicture.asset(
                        _borderMapAsset,
                        fit: BoxFit.fill,
                        allowDrawingOutsideViewBox: false,
                      ),
                      CustomPaint(
                        painter: TerritoryOverlayPainter(
                          state: widget.state,
                          territoryPaths: paths,
                          territoryHighlightPaths: highlightPaths,
                          territoryLabelAnchors: labelAnchors,
                          validTargetIds: widget.validTargetIds,
                          mapZoom: mapZoom,
                          paintLabelsAndHighlights: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
    final boundaries = territory.visualBoundaries;
    if (boundaries.isEmpty) {
      return _pathsForTerritory(territory, size).first;
    }
    if (boundaries.length == 1) {
      return _pathForBoundary(boundaries.first, size);
    }

    final points = <Offset>[];
    for (final boundary in boundaries) {
      for (final point in boundary) {
        points.add(Offset(point.x * size.width, point.y * size.height));
      }
    }

    final hull = _convexHull(points);
    if (hull.length < 3) {
      return _pathForBoundary(boundaries.first, size);
    }

    final path = Path()..moveTo(hull.first.dx, hull.first.dy);
    for (final point in hull.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
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
    final desired = Offset(territory.x * size.width, territory.y * size.height);
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

  List<Offset> _convexHull(List<Offset> points) {
    if (points.length <= 3) {
      return points;
    }

    final sorted = points.toList()
      ..sort((a, b) {
        final xComparison = a.dx.compareTo(b.dx);
        if (xComparison != 0) {
          return xComparison;
        }
        return a.dy.compareTo(b.dy);
      });

    final lower = <Offset>[];
    for (final point in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower.last, point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }

    final upper = <Offset>[];
    for (final point in sorted.reversed) {
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper.last, point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }

    lower.removeLast();
    upper.removeLast();
    return <Offset>[...lower, ...upper];
  }

  double _cross(Offset origin, Offset a, Offset b) {
    return (a.dx - origin.dx) * (b.dy - origin.dy) -
        (a.dy - origin.dy) * (b.dx - origin.dx);
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

  void _syncInitialView(Size viewportSize, Size mapSize) {
    if (_lastViewportSize == viewportSize && _lastMapSize == mapSize) {
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
    _transformationController.value = Matrix4.translationValues(dx, dy, 0);
  }
}
