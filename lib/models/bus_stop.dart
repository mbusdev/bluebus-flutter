import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusStop {
  final String id;
  final String name;
  final LatLng location;
  final String routeId;

  BusStop({required this.id, required this.name, required this.location, required this.routeId});

  factory BusStop.fromJson(Map<String, dynamic> json, String routeId) {
    return BusStop(
      id: json['stpid'] ?? '',
      name: json['stpnm'] ?? '',
      location: LatLng(json['lat']?.toDouble() ?? 0, json['lon']?.toDouble() ?? 0),
      routeId: routeId,
    );
  }
} 

class BusStopWithPrediction {
  final String id;
  final String name;
  final String prediction;

  BusStopWithPrediction({required this.id, required this.name, required this.prediction});

  factory BusStopWithPrediction.fromJson(Map<String, dynamic> json) {
    return BusStopWithPrediction(
      id: json['stpid'] ?? '',
      name: json['stpnm'] ?? '',
      prediction: json['prdctdn'] as String,
    );
  }
} 

class BusWithPrediction {
  final String id;
  final String destination;
  final String prediction;
  final String direction;

  BusWithPrediction({required this.id, required this.destination, required this.prediction, required this.direction});

  factory BusWithPrediction.fromJson(Map<String, dynamic> json) {
    return BusWithPrediction(
      id: json['rt'] ?? '',
      destination: json['des'] ?? '',
      prediction: json['prdctdn'] as String,
      direction: json['rtdir'] as String,
    );
  }
} 