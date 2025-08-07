import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Backend url for the api
//const String BACKEND_URL = 'https://mbus-310c2b44573c.herokuapp.com/mbus/api/v3/'; 
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://www.efeakinci.host/mbus/api/v3');
const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000/mbus/api/v3');

// Mapping from route code to full name
const Map<String, String> ROUTE_CODE_TO_NAME = {
  'CN': 'Commuter North',
  'CSX': 'Crisler Express',
  'MX': 'Med Express',
  'WS': 'Wall Street-NIB',
  'WX': 'Wall Street Express',
  'CS': 'Commuter South',
  'NW': 'Northwood',
  'NES': 'North-East Shuttle',
};

String getPrettyRouteName(String code) {
  final name = ROUTE_CODE_TO_NAME[code];
  return name != null ? name : code;
}

// COLORS
const Color maizeBusDarkBlue = Color.fromARGB(255, 10, 0, 89);

//data types
class Location {
  final String name;
  final String abbrev;
  final List<String> aliases;

  final int? stopId;
  final LatLng? latlng;

  final bool isBusStop;

  Location(
    this.name,
    this.abbrev,
    List<String> aliases,
    this.isBusStop, {
    this.stopId,
    this.latlng,
  }) : aliases = aliases;
}