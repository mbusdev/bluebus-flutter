import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'bus_stop.dart';

class BusRouteLine {
  final String routeId;
  final List<LatLng> points;
  final List<BusStop> stops;
  final Color? color;
  final String? imageUrl;

  BusRouteLine({
    required this.routeId, 
    required this.points, 
    required this.stops,
    this.color,
    this.imageUrl,
  });
} 