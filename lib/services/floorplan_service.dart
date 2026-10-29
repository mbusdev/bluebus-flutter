import 'dart:convert';

import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/utils/floorplan_projection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A floorplan together with the real world positions of the two waypoint POIs
/// it carries, which is everything needed to place it on the map.
class GeoreferencedFloorplan {
  final Floorplan floorplan;

  /// Real world position of the floor's `waypoint1` POI.
  final LatLng waypoint1;

  /// Real world position of the floor's `waypoint2` POI.
  final LatLng waypoint2;

  const GeoreferencedFloorplan({
    required this.floorplan,
    required this.waypoint1,
    required this.waypoint2,
  });
}

/// A searchable POI with its floor context and precomputed map position.
class LocatedFloorplanPoi {
  final String building;
  final FloorplanFloor floor;
  final FloorplanPoi poi;
  final LatLng position;

  const LocatedFloorplanPoi(this.building, this.floor, this.poi, this.position);
}

// A search index of floorplan POIs with real-world lat/lng coordinates
class FloorplanPoiIndex {
  final List<LocatedFloorplanPoi> pois;

  FloorplanPoiIndex(GeoreferencedFloorplan source)
    : pois = [
        // Spread each floor's projected POIs into one searchable list.
        for (final floor in source.floorplan.floors)
          ..._projectFloor(source, floor),
      ];

  // converts a floor's POIs from floorplan pixel coords to real-world lat/lng coords
  static Iterable<LocatedFloorplanPoi> _projectFloor(
    GeoreferencedFloorplan source,
    FloorplanFloor floor,
  ) sync* {
    // Use the floor's reference markers to convert plan pixels to lat/lng.
    final projection = FloorplanProjection.forFloor(
      floor,
      waypoint1: source.waypoint1,
      waypoint2: source.waypoint2,
    );
    // Skip floors that cannot be positioned on the map.
    if (projection == null) return;
    for (final poi in floor.pois) {
      // Waypoints position the floorplan; they are not searchable destinations.
      if (poi.type == FloorplanTypes.waypoint1 ||
          poi.type == FloorplanTypes.waypoint2) {
        continue;
      }
      // Keep building and floor context alongside the POI's map position.
      yield LocatedFloorplanPoi(
        source.floorplan.building,
        floor,
        poi,
        projection.toLatLng(poi.position),
      );
    }
  }

  // Returns up to [limit] POIs of [type], ordered by geographic distance from the [origin] parameter
  // (this does not account for walking routes or travel between floors right now)
  List<LocatedFloorplanPoi> nearest(
    String type,
    LatLng origin, {
    int limit = 5,
  }) {
    // Filter by type and pair each matching POI with its distance in meters.
    final matches = [
      for (final entry in pois)
        if (entry.poi.type == type)
          (
            entry: entry,
            distance: Geolocator.distanceBetween(
              origin.latitude,
              origin.longitude,
              entry.position.latitude,
              entry.position.longitude,
            ),
          ),
    ]..sort((a, b) => a.distance.compareTo(b.distance)); // Nearest first.
    // Drop the temporary distances and return only the requested POI entries.
    return matches.take(limit).map((match) => match.entry).toList();
  }
}

/// Loads floorplans.
///
/// Right now floorplans ship with the app as a bundled asset. Eventually the
/// backend will serve them (behind a security check), at which point only the
/// loading in here has to change -- everything downstream works off
/// [GeoreferencedFloorplan].
class FloorplanService {
  static const String _duderstadtAsset = 'assets/floorplans/dudeMap.json';

  // TODO: The backend should send these alongside the floorplan once floorplans
  // are served rather than bundled. They're the surveyed real world positions
  // of the `waypoint1` / `waypoint2` POIs in the Duderstadt plan.
  static const LatLng _duderstadtWaypoint1 = LatLng(
    42.29127928001248,
    -83.71682770735084,
  );
  static const LatLng _duderstadtWaypoint2 = LatLng(
    42.29127928001248,
    -83.7166406232747,
  );

  static Future<GeoreferencedFloorplan>? _duderstadt;

  /// The one floorplan we currently have. Parsed once and shared; repeat calls
  /// get the same future back.
  static Future<GeoreferencedFloorplan> loadDuderstadt() {
    return _duderstadt ??= _loadFromAsset(
      _duderstadtAsset,
      waypoint1: _duderstadtWaypoint1,
      waypoint2: _duderstadtWaypoint2,
    );
  }

  static Future<GeoreferencedFloorplan> _loadFromAsset(
    String assetPath, {
    required LatLng waypoint1,
    required LatLng waypoint2,
  }) async {
    final String raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return GeoreferencedFloorplan(
      floorplan: Floorplan.fromJson(json),
      waypoint1: waypoint1,
      waypoint2: waypoint2,
    );
  }
}
