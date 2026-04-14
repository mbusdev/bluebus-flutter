class BuildingFloors {
  final String buildingId;
  final List<int> floors;
  final List<Node> nodes;
  final List<Edge> edges;

  BuildingFloors({required this.buildingId, required this.floors, required this.nodes, required this.edges});

  factory BuildingFloors.fromJson(Map<String, dynamic> j) => BuildingFloors(
    buildingId: j['buildingId'],
    floors: [j['floor'] as int],
    nodes: (j['nodes'] as List).map((e) => Node.fromJson(e)).toList(),
    edges: (j['edges'] as List).map((e) => Edge.fromJson(e)).toList(),
  );

  @override
  String toString() => 'BuildingFloors($buildingId, $floors, $nodes, $edges)';
}

class Node {
  final String id;
  final String name;
  final int floor;
  final String type;
  final double x;
  final double y;

  Node({required this.id, required this.name, required this.floor, required this.type, required this.x, required this.y});

  factory Node.fromJson(Map<String, dynamic> j) => Node(
    id: j['id'],
    name: j['name'],
    floor: j['floor'],
    type: j['type'],
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  );

  @override
  String toString() => 'Node($id, $type, "$name", ($x, $y))';
}

class Edge {
  final String id;
  final String from;
  final String to;
  final String type;
  final double cost;

  Edge({required this.id, required this.from, required this.to, required this.type, required this.cost});

  factory Edge.fromJson(Map<String, dynamic> j) => Edge(
    id: j['id'], from: j['from'], to: j['to'],
    type: j['type'], cost: j['cost'],
  );

  @override
  String toString() => 'Edge($id, $from, $to, $type, $cost)';
}
