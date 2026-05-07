const Object _territorySentinel = Object();

class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'x': x,
      'y': y,
    };
  }

  factory MapPoint.fromMap(Map<String, dynamic> map) {
    return MapPoint(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
    );
  }
}

class Territory {
  Territory({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.ownerId,
    required this.armyCount,
    required List<String> neighbors,
    required this.continent,
    List<MapPoint> boundary = const <MapPoint>[],
  })  : neighbors = List<String>.unmodifiable(neighbors),
        boundary = List<MapPoint>.unmodifiable(boundary);

  final String id;
  final String name;
  final double x;
  final double y;
  final String? ownerId;
  final int armyCount;
  final List<String> neighbors;
  final String continent;
  final List<MapPoint> boundary;

  Territory copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    Object? ownerId = _territorySentinel,
    int? armyCount,
    List<String>? neighbors,
    String? continent,
    List<MapPoint>? boundary,
  }) {
    return Territory(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      ownerId: identical(ownerId, _territorySentinel)
          ? this.ownerId
          : ownerId as String?,
      armyCount: armyCount ?? this.armyCount,
      neighbors: neighbors ?? this.neighbors,
      continent: continent ?? this.continent,
      boundary: boundary ?? this.boundary,
    );
  }

  bool isNeighbor(String territoryId) => neighbors.contains(territoryId);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'x': x,
      'y': y,
      'ownerId': ownerId,
      'armyCount': armyCount,
      'neighbors': neighbors,
      'continent': continent,
      'boundary': boundary.map((point) => point.toMap()).toList(),
    };
  }

  factory Territory.fromMap(Map<String, dynamic> map) {
    return Territory(
      id: map['id'] as String,
      name: map['name'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      ownerId: map['ownerId'] as String?,
      armyCount: map['armyCount'] as int,
      neighbors: List<String>.from(map['neighbors'] as List<dynamic>),
      continent: map['continent'] as String,
      boundary: (map['boundary'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (point) => MapPoint.fromMap(
              Map<String, dynamic>.from(point as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}
