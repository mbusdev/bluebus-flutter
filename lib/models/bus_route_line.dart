import 'package:bluebus/models/lat_lng.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'bus_stop.dart';
import 'package:bluebus/backend/export.dart' as backend;

class BusRouteLine {
  final String routeId;
  final List<LatLng> points;

  /// bus stops along with the index of the associated point
  // INVARIANT: indicies are in ascending order
  final List<(int, BusStop)> stops;
  final Color? color;
  final String? imageUrl;

  BusRouteLine({
    required this.routeId,
    required this.points,
    required this.stops,
    this.color,
    this.imageUrl,
  });

  static BusRouteLine fromBackend(backend.BusRouteLine line, Color? color, String? imageUrl) {
    return BusRouteLine(
      routeId: line.routeId,
      points: line.points.map(latLngFromBackend).toList(),
      stops: line.stops.map((x) => (x.index, BusStop.fromBackend(x.stop))).toList(),
      color: color,
      imageUrl: imageUrl
    );
  }
}
