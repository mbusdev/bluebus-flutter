import 'dart:ui' show Offset;

/// Data model for an indoor floorplan.
///
/// Coordinates in this file are *plan pixels* -- the arbitrary coordinate space
/// the floorplan was authored in. They are NOT latitude/longitude. Use a
/// [FloorplanProjection] to convert them into real world coordinates before
/// handing them to the map.

/// Convenience for the `[x, y]` pairs the floorplan JSON uses everywhere.
Offset _pointFromJson(dynamic json) {
  final pair = json as List<dynamic>;
  return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
}

List<Offset> _polygonFromJson(dynamic json) =>
    (json as List<dynamic>? ?? const []).map(_pointFromJson).toList();

/// POI and room `type` values we care about. These come from the backend as
/// free-form strings, so treat this as a list of known values rather than an
/// exhaustive one -- anything unrecognized should degrade gracefully.
abstract final class FloorplanTypes {
  static const String room = 'room';
  static const String door = 'door';
  static const String elevator = 'elevator';
  static const String escalator = 'escalator';
  static const String stairway = 'stairway';
  static const String inaccessible = 'inaccessible';
  static const String information = 'information';
  static const String food = 'food';
  static const String vendingMachine = 'vending_machine';
  static const String femaleBathroom = 'female_bathroom';
  static const String maleBathroom = 'male_bathroom';
  static const String neutralBathroom = 'neutral_bathroom';

  /// The two georeferencing markers a floor carries so we can line its plan
  /// pixels up with the real world. See [FloorplanProjection].
  static const String waypoint1 = 'waypoint1';
  static const String waypoint2 = 'waypoint2';
}

/// One building's floorplan, covering every floor we have data for.
class Floorplan {
  final String building;
  final List<FloorplanFloor> floors;

  const Floorplan({required this.building, required this.floors});

  factory Floorplan.fromJson(Map<String, dynamic> json) => Floorplan(
    building: json['building'] as String? ?? 'Unknown Building',
    floors: (json['floors'] as List<dynamic>? ?? const [])
        .map((floor) => FloorplanFloor.fromJson(floor as Map<String, dynamic>))
        .toList(),
  );
}

/// A single floor: everything needed to draw it and (eventually) route through it.
class FloorplanFloor {
  final String id;
  final String name;

  /// Plan pixels per real-world meter. Kept for reference; the drawn scale is
  /// derived from the waypoints instead, since those are what we georeference against.
  final double pxPerMeter;
  final double width;
  final double height;

  /// Individual wall segments, drawn as lines.
  final List<FloorplanWall> walls;

  /// Closed room polygons, drawn filled.
  final List<FloorplanRoom> rooms;

  /// Points of interest: room labels, bathrooms, elevators, waypoints, etc.
  final List<FloorplanPoi> pois;

  /// A single closed polygon tracing the outside of the whole building.
  final List<Offset> outline;

  /// Pathfinding graph. Not drawn -- incomplete in the current data.
  final FloorplanNavGraph nav;

  const FloorplanFloor({
    required this.id,
    required this.name,
    required this.pxPerMeter,
    required this.width,
    required this.height,
    required this.walls,
    required this.rooms,
    required this.pois,
    required this.outline,
    required this.nav,
  });

  factory FloorplanFloor.fromJson(Map<String, dynamic> json) => FloorplanFloor(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    pxPerMeter: (json['pxPerMeter'] as num?)?.toDouble() ?? 1.0,
    width: (json['width'] as num?)?.toDouble() ?? 0.0,
    height: (json['height'] as num?)?.toDouble() ?? 0.0,
    walls: (json['walls'] as List<dynamic>? ?? const [])
        .map((wall) => FloorplanWall.fromJson(wall as Map<String, dynamic>))
        .toList(),
    rooms: (json['rooms'] as List<dynamic>? ?? const [])
        .map((room) => FloorplanRoom.fromJson(room as Map<String, dynamic>))
        .toList(),
    pois: (json['pois'] as List<dynamic>? ?? const [])
        .map((poi) => FloorplanPoi.fromJson(poi as Map<String, dynamic>))
        .toList(),
    outline: _polygonFromJson(json['outline']),
    nav: FloorplanNavGraph.fromJson(json['nav'] as Map<String, dynamic>?),
  );

  /// The first POI with the given type, or null if this floor has none.
  FloorplanPoi? findPoiByType(String type) {
    for (final poi in pois) {
      if (poi.type == type) return poi;
    }
    return null;
  }
}

/// A straight wall segment in plan pixels.
class FloorplanWall {
  final Offset start;
  final Offset end;

  const FloorplanWall({required this.start, required this.end});

  factory FloorplanWall.fromJson(Map<String, dynamic> json) => FloorplanWall(
    start: _pointFromJson(json['start']),
    end: _pointFromJson(json['end']),
  );
}

/// A closed room polygon in plan pixels.
class FloorplanRoom {
  final String id;
  final String name;

  /// One of [FloorplanTypes]; decides how the room is filled.
  final String type;
  final List<Offset> polygon;

  /// The POI that labels this room, if any.
  final String? poiId;

  const FloorplanRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.polygon,
    required this.poiId,
  });

  factory FloorplanRoom.fromJson(Map<String, dynamic> json) => FloorplanRoom(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    polygon: _polygonFromJson(json['polygon']),
    poiId: json['poiId'] as String?,
  );
}

/// A point of interest in plan pixels.
class FloorplanPoi {
  final String id;
  final Offset position;

  /// One of [FloorplanTypes]; decides which label and/or icon we draw.
  final String type;
  final String? name;
  final String? roomId;
  final String? navNodeId;

  const FloorplanPoi({
    required this.id,
    required this.position,
    required this.type,
    required this.name,
    required this.roomId,
    required this.navNodeId,
  });

  factory FloorplanPoi.fromJson(Map<String, dynamic> json) => FloorplanPoi(
    id: json['id'] as String? ?? '',
    position: Offset(
      (json['x'] as num?)?.toDouble() ?? 0.0,
      (json['y'] as num?)?.toDouble() ?? 0.0,
    ),
    type: json['type'] as String? ?? '',
    name: json['name'] as String?,
    roomId: json['roomId'] as String?,
    navNodeId: json['navNodeId'] as String?,
  );
}

/// The (currently incomplete) walkable graph used for indoor pathfinding.
class FloorplanNavGraph {
  final List<FloorplanNavNode> nodes;
  final List<FloorplanNavEdge> edges;

  const FloorplanNavGraph({required this.nodes, required this.edges});

  factory FloorplanNavGraph.fromJson(Map<String, dynamic>? json) =>
      FloorplanNavGraph(
        nodes: (json?['nodes'] as List<dynamic>? ?? const [])
            .map((node) => FloorplanNavNode.fromJson(node as Map<String, dynamic>))
            .toList(),
        edges: (json?['edges'] as List<dynamic>? ?? const [])
            .map((edge) => FloorplanNavEdge.fromJson(edge as Map<String, dynamic>))
            .toList(),
      );
}

class FloorplanNavNode {
  final String id;
  final Offset position;

  const FloorplanNavNode({required this.id, required this.position});

  factory FloorplanNavNode.fromJson(Map<String, dynamic> json) =>
      FloorplanNavNode(
        id: json['id'] as String? ?? '',
        position: Offset(
          (json['x'] as num?)?.toDouble() ?? 0.0,
          (json['y'] as num?)?.toDouble() ?? 0.0,
        ),
      );
}

class FloorplanNavEdge {
  final String from;
  final String to;

  const FloorplanNavEdge({required this.from, required this.to});

  factory FloorplanNavEdge.fromJson(Map<String, dynamic> json) =>
      FloorplanNavEdge(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
      );
}
