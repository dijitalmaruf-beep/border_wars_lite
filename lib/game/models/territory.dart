const Object _territorySentinel = Object();

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
  }) : neighbors = List<String>.unmodifiable(neighbors);

  final String id;
  final String name;
  final double x;
  final double y;
  final String? ownerId;
  final int armyCount;
  final List<String> neighbors;
  final String continent;

  Territory copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    Object? ownerId = _territorySentinel,
    int? armyCount,
    List<String>? neighbors,
    String? continent,
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
    );
  }
}
