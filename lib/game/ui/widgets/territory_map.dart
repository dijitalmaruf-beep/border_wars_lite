import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../models/territory.dart';
import 'world_map_painter.dart';

class TerritoryMap extends StatefulWidget {
  const TerritoryMap({
    required this.state,
    required this.onTerritoryTap,
    super.key,
  });

  final GameState state;
  final ValueChanged<String> onTerritoryTap;

  @override
  State<TerritoryMap> createState() => _TerritoryMapState();
}

class _TerritoryMapState extends State<TerritoryMap> {
  Size? _cachedSize;
  Map<String, Path> _cachedPaths = const <String, Path>{};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final paths = _pathsFor(size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final territoryId = _territoryAt(details.localPosition, paths);
            if (territoryId != null) {
              widget.onTerritoryTap(territoryId);
            }
          },
          child: CustomPaint(
            painter: WorldMapPainter(
              state: widget.state,
              territoryPaths: paths,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Map<String, Path> _pathsFor(Size size) {
    if (_cachedSize == size && _cachedPaths.isNotEmpty) {
      return _cachedPaths;
    }

    _cachedSize = size;
    _cachedPaths = <String, Path>{
      for (final territory in widget.state.territories)
        territory.id: _pathForTerritory(territory, size),
    };
    return _cachedPaths;
  }

  Path _pathForTerritory(Territory territory, Size size) {
    final path = Path();
    final boundary = territory.boundary;
    if (boundary.isEmpty) {
      final center = Offset(territory.x * size.width, territory.y * size.height);
      path.addRect(Rect.fromCenter(center: center, width: 8, height: 8));
      return path;
    }

    path.moveTo(boundary.first.x * size.width, boundary.first.y * size.height);
    for (final point in boundary.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    path.close();
    return path;
  }

  String? _territoryAt(Offset position, Map<String, Path> paths) {
    for (final territory in widget.state.territories.reversed) {
      final path = paths[territory.id];
      if (path != null && path.contains(position)) {
        return territory.id;
      }
    }
    return null;
  }
}
