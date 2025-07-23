import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bus_stop.dart';

class BusRouteLine {
  final String routeId;
  final List<LatLng> points;
  final List<BusStop> stops;

  BusRouteLine({required this.routeId, required this.points, required this.stops});
} 