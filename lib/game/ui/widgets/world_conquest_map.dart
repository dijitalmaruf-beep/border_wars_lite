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
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
  final Set<String> validSourceIds;
  final Set<String> validTargetIds;
  final ValueChanged<String> onTerritoryTap;

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
                          validSourceIds: widget.validSourceIds,
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
                          validSourceIds: widget.validSourceIds,
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
