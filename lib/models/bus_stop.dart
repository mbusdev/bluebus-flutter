import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';
import 'package:bluebus/backend/export.dart' as backend;

class BusStop {
  final String id;
  final String name;
  final LatLng location;
  final String routeId;
  final double rotation;
  final bool isRide;

  BusStop({required this.id, required this.name, required this.location, required this.routeId, required this.rotation, required this.isRide});

  factory BusStop.fromBackend(backend.BusStop x) {
    return BusStop(
      id: x.id,
      name: x.name,
      location: LatLng(x.location.lat.toDouble(),
      x.location.lon.toDouble()),
      routeId: x.routeId,
      rotation: x.rotation.toDouble(),
      isRide: x.isRide
    );
  }
} 

class BusStopWithPrediction {
  final String id;
  final String name;
  final String prediction;
  final String busRouteCode;

  BusStopWithPrediction({required this.id, required this.name, required this.prediction, required this.busRouteCode});

  factory BusStopWithPrediction.fromJson(Map<String, dynamic> json) {
    return BusStopWithPrediction(
      id: json['stpid'] ?? '',
      name: normalizeStopName(json['stpnm'] ?? ''),
      prediction: json['prdctdn'] as String,
      busRouteCode: json['rt'] ?? ''
    );
  }
} 

class BusWithPrediction {
  final String id;
  final String destination;
  final String prediction;
  final String direction;
  String vehicleId = "none";

  BusWithPrediction({required this.id, required this.destination, required this.prediction, required this.direction, required this.vehicleId});

  factory BusWithPrediction.fromJson(Map<String, dynamic> json) {
    return BusWithPrediction(
      id: json['rt'] ?? '',
      destination: normalizeStopName(json['des'] ?? ''),
      prediction: json['prdctdn'] as String,
      direction: json['rtdir'] as String,
      vehicleId: json['vid'] ?? 'none'
    );
  }
} 
