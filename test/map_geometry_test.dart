import 'dart:math' as math;

import 'package:chroma_conquest/game/data/sample_world_map.dart';
import 'package:chroma_conquest/game/models/territory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playable territory overlays do not materially overlap', () {
    final overlaps = <String>[];

    for (var i = 0; i < sampleWorldTerritories.length; i += 1) {
      for (var j = i + 1; j < sampleWorldTerritories.length; j += 1) {
        final first = sampleWorldTerritories[i];
        final second = sampleWorldTerritories[j];
        final overlap = _estimatedOverlapArea(first, second);

        if (overlap > 0.00045) {
          overlaps.add(
            '${first.id} overlaps ${second.id} '
            '(${overlap.toStringAsFixed(5)})',
          );
        }
      }
    }

    expect(overlaps, isEmpty, reason: overlaps.join('\n'));
  });
}

double _estimatedOverlapArea(Territory first, Territory second) {
  final firstBounds = _boundsFor(first);
  final secondBounds = _boundsFor(second);
  final overlapBounds = _intersect(firstBounds, secondBounds);
  if (overlapBounds == null) {
    return 0;
  }

  const columns = 34;
  const rows = 34;
  var overlapSamples = 0;
  final stepX = overlapBounds.width / columns;
  final stepY = overlapBounds.height / rows;

  for (var row = 0; row < rows; row += 1) {
    for (var column = 0; column < columns; column += 1) {
      final point = MapPoint(
        overlapBounds.left + stepX * (column + 0.5),
        overlapBounds.top + stepY * (row + 0.5),
      );
      if (_contains(first, point) && _contains(second, point)) {
        overlapSamples += 1;
      }
    }
  }

  final sampleRatio = overlapSamples / (columns * rows);
  return overlapBounds.width * overlapBounds.height * sampleRatio;
}

_Bounds _boundsFor(Territory territory) {
  var left = double.infinity;
  var top = double.infinity;
  var right = -double.infinity;
  var bottom = -double.infinity;

  for (final group in territory.visualBoundaries) {
    for (final point in group) {
      left = math.min(left, point.x);
      top = math.min(top, point.y);
      right = math.max(right, point.x);
      bottom = math.max(bottom, point.y);
    }
  }

  return _Bounds(left: left, top: top, right: right, bottom: bottom);
}

_Bounds? _intersect(_Bounds first, _Bounds second) {
  final left = math.max(first.left, second.left);
  final top = math.max(first.top, second.top);
  final right = math.min(first.right, second.right);
  final bottom = math.min(first.bottom, second.bottom);

  if (right <= left || bottom <= top) {
    return null;
  }
  return _Bounds(left: left, top: top, right: right, bottom: bottom);
}

bool _contains(Territory territory, MapPoint point) {
  return territory.visualBoundaries.any(
    (group) => _containsPoint(group, point),
  );
}

bool _containsPoint(List<MapPoint> polygon, MapPoint point) {
  if (polygon.length < 3) {
    return false;
  }

  var isInside = false;
  var previous = polygon.length - 1;
  for (var current = 0; current < polygon.length; current += 1) {
    final currentPoint = polygon[current];
    final previousPoint = polygon[previous];
    final crossesY = (currentPoint.y > point.y) != (previousPoint.y > point.y);
    final intersectionX =
        (previousPoint.x - currentPoint.x) *
            (point.y - currentPoint.y) /
            (previousPoint.y - currentPoint.y) +
        currentPoint.x;
    if (crossesY && point.x < intersectionX) {
      isInside = !isInside;
    }
    previous = current;
  }

  return isInside;
}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}
