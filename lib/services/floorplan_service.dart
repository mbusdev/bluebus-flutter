import 'dart:convert';

import 'package:bluebus/models/floorplan.dart';
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
