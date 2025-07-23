import 'package:google_maps_flutter/google_maps_flutter.dart';

class Bus {
  final String id;
  final LatLng position;
  final String routeId;
  final double heading;
  final String fullness;

  Bus({required this.id, required this.position, required this.routeId, required this.heading, required this.fullness});

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['vid'] ?? '',
      position: LatLng(double.parse(json['lat']), double.parse(json['lon'])),
      routeId: json['rt'] ?? '',
      heading: double.tryParse(json['hdg'] ?? '0') ?? 0,
      fullness: json['psgld'] ?? 'HALF_EMPTY',
    );
  }
} 