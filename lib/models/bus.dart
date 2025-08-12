import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class Bus {
  final String id;
  final LatLng position;
  final String routeId;
  final double heading;
  final String fullness;
  final Color? routeColor;
  final String? routeImageUrl;

  Bus({
    required this.id, 
    required this.position, 
    required this.routeId, 
    required this.heading, 
    required this.fullness,
    this.routeColor,
    this.routeImageUrl,
  });
  
  factory Bus.fromJson(Map<String, dynamic> json, {Color? routeColor, String? routeImageUrl}) {
    return Bus(
      id: json['vid'] ?? '',
      position: LatLng(double.parse(json['lat']), double.parse(json['lon'])),
      routeId: json['rt'] ?? '',
      heading: double.tryParse(json['hdg'] ?? '0') ?? 0,
      fullness: json['psgld'] ?? 'HALF_EMPTY',
      routeColor: routeColor,
      routeImageUrl: routeImageUrl,
    );
  }
} 