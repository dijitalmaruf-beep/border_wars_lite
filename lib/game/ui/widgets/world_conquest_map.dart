import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/game_state.dart';
import '../../models/territory.dart';
import 'territory_overlay_painter.dart';

class WorldConquestMap extends StatefulWidget {
  const WorldConquestMap({
    required this.state,
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
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
  static const _portraitMapZoom = 1.0;

  final TransformationController _transformationController =
      TransformationController();

  Size? _cachedSize;
  Size? _lastMapSize;
  Size? _lastViewportSize;
  Map<String, List<Path>> _cachedPaths = const <String, List<Path>>{};

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
    return _cachedPaths;
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

  String? _territoryAt(Offset position, Map<String, List<Path>> paths) {
    for (final territory in widget.state.territories.reversed) {
      final territoryPaths = paths[territory.id] ?? const <Path>[];
      if (territoryPaths.any((path) => path.contains(position))) {
        return territory.id;
      }
    }
    return null;
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
    final dy = mapSize.height <= viewportSize.height + 0.5
        ? (viewportSize.height - mapSize.height) / 2
        : viewportSize.height / 2 - mapSize.height * _portraitOpeningCenterY;
    _transformationController.value = Matrix4.translationValues(dx, dy, 0);
  }
}
