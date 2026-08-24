
import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/services/floorplan_marker_service.dart';
import 'package:bluebus/services/floorplan_service.dart';
import 'package:bluebus/services/floorplan_style.dart';
import 'package:bluebus/utils/floorplan_projection.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws indoor floorplans on top of the map.
///
/// The layer swaps between three depths of detail as the camera zooms (see
/// [FloorplanDetailLevel]). All of the geometry for a floor is projected and
/// built once when the floor is loaded, and a zoom change only swaps which
/// prebuilt sets are exposed to the map -- no re-projection happens while the
/// user is panning around.
class FloorplansLayer extends CompositeMapLayer {
  @override
  bool isVisible = true;
  @override
  Set<Polygon> polygons = const {};
  @override
  Set<Polyline> polylines = const {};
  @override
  Set<Marker> markers = const {};
  @override
  Function() onUpdate = () {};

  GeoreferencedFloorplan? _source;
  int _floorIndex = 0;

  /// Starts out matching the map's initial camera, since [onCameraMove] only
  /// fires once the user actually moves.
  FloorplanDetailLevel _detailLevel = floorplanDetailLevelForZoom(
    INITIAL_MAP_ZOOM,
  );

  /// Bumped whenever a rebuild starts, so a slow rebuild that has been
  /// superseded (by a floor change, say) can bail out instead of overwriting
  /// newer geometry.
  int _buildGeneration = 0;

  // Prebuilt geometry for the active floor, one set per thing we draw.
  Set<Polygon> _footprintPolygons = const {};
  Set<Polygon> _detailedPolygons = const {};
  Set<Polyline> _wallPolylines = const {};
  Set<Marker> _poiMarkers = const {};

  Floorplan? get floorplan => _source?.floorplan;

  List<FloorplanFloor> get floors => _source?.floorplan.floors ?? const [];

  FloorplanFloor? get activeFloor {
    final List<FloorplanFloor> all = floors;
    if (_floorIndex < 0 || _floorIndex >= all.length) return null;
    return all[_floorIndex];
  }

  Future<void>? _loading;

  /// Loads the floorplan and builds the first floor's geometry. Awaiting this
  /// more than once is free -- the work only happens on the first call, so
  /// anything that needs the floors can just await it.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _source = await FloorplanService.loadDuderstadt();
    } catch (err) {
      debugPrint('FloorplansLayer: failed to load floorplan ($err)');
      return;
    }
    await _rebuild();
  }

  /// Switches which floor is drawn. Safe to call before [load] finishes.
  Future<void> setFloorIndex(int index) async {
    if (index == _floorIndex) return;
    _floorIndex = index;
    await _rebuild();
  }

  @override
  void onCameraMove(CameraPosition oldPosition, CameraPosition newPosition) {
    final FloorplanDetailLevel level = floorplanDetailLevelForZoom(
      newPosition.zoom,
    );
    if (level == _detailLevel) return;

    _detailLevel = level;
    _applyDetailLevel();
    if (isVisible) onUpdate();
  }

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  // --- Geometry ------------------------------------------------------------

  Future<void> _rebuild() async {
    final int generation = ++_buildGeneration;

    _footprintPolygons = const {};
    _detailedPolygons = const {};
    _wallPolylines = const {};
    _poiMarkers = const {};

    final FloorplanFloor? floor = activeFloor;
    final GeoreferencedFloorplan? source = _source;

    if (floor != null && source != null) {
      final FloorplanProjection? projection = FloorplanProjection.forFloor(
        floor,
        waypoint1: source.waypoint1,
        waypoint2: source.waypoint2,
      );

      if (projection == null) {
        // Without both waypoints we can't know where the floor sits in the
        // world, so there's nothing safe to draw.
        debugPrint(
          'FloorplansLayer: floor "${floor.id}" is missing its waypoints',
        );
      } else {
        final List<LatLng> outline = projection.toLatLngList(floor.outline);

        _footprintPolygons = {_buildFootprintPolygon(floor, outline)};
        _detailedPolygons = {
          _buildBasePolygon(floor, outline),
          ..._buildRoomPolygons(floor, projection),
        };
        _wallPolylines = _buildWallPolylines(floor, projection);

        final Set<Marker> poiMarkers = await _buildPoiMarkers(floor, projection);
        if (generation != _buildGeneration) return; // Superseded mid-build.
        _poiMarkers = poiMarkers;
      }
    }

    _applyDetailLevel();
    if (isVisible) onUpdate();
  }

  /// The plain filled blob shown when we're zoomed too far out for detail.
  Polygon _buildFootprintPolygon(FloorplanFloor floor, List<LatLng> outline) {
    return Polygon(
      polygonId: PolygonId('floorplan_footprint_${floor.id}'),
      points: outline,
      fillColor: FLOORPLAN_FAR_OUTLINE_FILL,
      strokeColor: FLOORPLAN_FAR_OUTLINE_STROKE,
      strokeWidth: FLOORPLAN_FAR_OUTLINE_STROKE_WIDTH,
      zIndex: FLOORPLAN_Z_BASE,
    );
  }

  /// The same outline again, this time as the backdrop the detailed plan is
  /// drawn on top of.
  Polygon _buildBasePolygon(FloorplanFloor floor, List<LatLng> outline) {
    return Polygon(
      polygonId: PolygonId('floorplan_base_${floor.id}'),
      points: outline,
      fillColor: FLOORPLAN_BASE_FILL,
      strokeColor: FLOORPLAN_STROKE,
      strokeWidth: FLOORPLAN_BASE_STROKE_WIDTH,
      zIndex: FLOORPLAN_Z_BASE,
    );
  }

  Set<Polygon> _buildRoomPolygons(
    FloorplanFloor floor,
    FloorplanProjection projection,
  ) {
    return {
      for (final FloorplanRoom room in floor.rooms)
        if (room.polygon.length >= 3)
          Polygon(
            polygonId: PolygonId('floorplan_room_${room.id}'),
            points: projection.toLatLngList(room.polygon),
            fillColor: floorplanRoomFill(room.type),
            strokeColor: FLOORPLAN_STROKE,
            strokeWidth: FLOORPLAN_ROOM_STROKE_WIDTH,
            zIndex: FLOORPLAN_Z_ROOMS,
          ),
    };
  }

  Set<Polyline> _buildWallPolylines(
    FloorplanFloor floor,
    FloorplanProjection projection,
  ) {
    final List<List<Offset>> chains = _chainWallSegments(floor.walls);
    return {
      for (int i = 0; i < chains.length; i++)
        Polyline(
          polylineId: PolylineId('floorplan_wall_${floor.id}_$i'),
          points: projection.toLatLngList(chains[i]),
          color: FLOORPLAN_STROKE,
          width: FLOORPLAN_WALL_STROKE_WIDTH,
          jointType: JointType.round,
          startCap: Cap.buttCap,
          endCap: Cap.buttCap,
          zIndex: FLOORPLAN_Z_WALLS,
        ),
    };
  }

  /// Room labels and POI icons. A POI can get both, in which case the label is
  /// pushed below the icon rather than drawn over it.
  Future<Set<Marker>> _buildPoiMarkers(
    FloorplanFloor floor,
    FloorplanProjection projection,
  ) async {
    final Set<Marker> result = {};

    for (final FloorplanPoi poi in floor.pois) {
      final bool hasIcon = FLOORPLAN_POI_ICONS.containsKey(poi.type);
      final String? name = poi.name;
      final bool hasLabel =
          FLOORPLAN_LABELED_POI_TYPES.contains(poi.type) &&
          name != null &&
          name.isNotEmpty;

      if (!hasIcon && !hasLabel) continue;

      final LatLng position = projection.toLatLng(poi.position);

      if (hasIcon) {
        final BitmapDescriptor? icon = await FloorplanMarkerService.icon(
          poi.type,
        );
        if (icon != null) {
          result.add(
            Marker(
              markerId: MarkerId('floorplan_icon_${poi.id}'),
              position: position,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: FLOORPLAN_Z_MARKERS,
            ),
          );
        }
      }

      if (hasLabel) {
        result.add(
          Marker(
            markerId: MarkerId('floorplan_label_${poi.id}'),
            position: position,
            icon: await FloorplanMarkerService.label(name, belowIcon: hasIcon),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: FLOORPLAN_Z_MARKERS,
          ),
        );
      }
    }

    return result;
  }

  /// Joins wall segments that meet end to end into longer polylines.
  ///
  /// The data has one entry per straight segment (~900 on the Duderstadt
  /// ground floor), and each one would otherwise become its own map object.
  /// Segments are merged wherever exactly two of them meet at a point, which
  /// cuts the object count roughly in half without changing what's drawn.
  /// Junctions where three or more walls meet stay split, since there's no
  /// unambiguous way to continue through them.
  static List<List<Offset>> _chainWallSegments(List<FloorplanWall> walls) {
    // Endpoints are matched on their rounded coordinates so that segments the
    // authoring tool wrote out separately still join up.
    String pointKey(Offset point) =>
        '${point.dx.toStringAsFixed(2)},${point.dy.toStringAsFixed(2)}';
    String segmentKey(String a, String b) =>
        a.compareTo(b) <= 0 ? '$a>$b' : '$b>$a';

    final Map<String, Offset> pointsByKey = {};
    final Map<String, Set<String>> neighbors = {};
    final Set<String> unusedSegments = {};

    for (final FloorplanWall wall in walls) {
      final String start = pointKey(wall.start);
      final String end = pointKey(wall.end);
      if (start == end) continue; // Zero length segment, nothing to draw.

      pointsByKey[start] = wall.start;
      pointsByKey[end] = wall.end;
      neighbors.putIfAbsent(start, () => {}).add(end);
      neighbors.putIfAbsent(end, () => {}).add(start);
      unusedSegments.add(segmentKey(start, end));
    }

    final List<List<Offset>> chains = [];

    while (unusedSegments.isNotEmpty) {
      final String seed = unusedSegments.first;
      unusedSegments.remove(seed);

      final List<String> chain = seed.split('>');

      // Grow the chain outward from each end for as long as the endpoint is a
      // simple pass-through with an unused segment left on it.
      for (final bool forward in const [true, false]) {
        while (true) {
          final String tip = forward ? chain.last : chain.first;
          final Set<String> tipNeighbors = neighbors[tip]!;
          if (tipNeighbors.length != 2) break;

          String? next;
          for (final String candidate in tipNeighbors) {
            if (unusedSegments.contains(segmentKey(tip, candidate))) {
              next = candidate;
              break;
            }
          }
          if (next == null) break;

          unusedSegments.remove(segmentKey(tip, next));
          if (forward) {
            chain.add(next);
          } else {
            chain.insert(0, next);
          }
        }
      }

      chains.add([for (final String key in chain) pointsByKey[key]!]);
    }

    return chains;
  }

  /// Points the map at whichever prebuilt sets the current zoom calls for.
  void _applyDetailLevel() {
    switch (_detailLevel) {
      case FloorplanDetailLevel.hidden:
        polygons = const {};
        polylines = const {};
        markers = const {};
      case FloorplanDetailLevel.outline:
        polygons = _footprintPolygons;
        polylines = const {};
        markers = const {};
      case FloorplanDetailLevel.full:
        polygons = _detailedPolygons;
        polylines = _wallPolylines;
        markers = const {};
      case FloorplanDetailLevel.labeled:
        polygons = _detailedPolygons;
        polylines = _wallPolylines;
        markers = _poiMarkers;
    }
  }
}
