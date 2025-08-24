import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Backend url for the api
const String BACKEND_URL = 'https://mbus-310c2b44573c.herokuapp.com/mbus/api/v3'; 
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://www.efeakinci.host/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment("BACKEND_URL", defaultValue: "http://10.0.2.2:3000/mbus/api/v3/");
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://192.168.0.247:3000/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000/mbus/api/v3/');

List<Map<String, String>> globalAvailableRoutes = [];

// Mapping from route code to full name
const Map<String, String> fallback_code_to_name = {
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
  for (Map<String, String> route in globalAvailableRoutes){
    if(route['id'] == code){
      return route['name'] ?? route['id']!;
    }
  }

  // fallback
  final name = fallback_code_to_name[code];
  return name != null ? name : code;
}

// COLORS
const Color maizeBusDarkBlue = Color.fromARGB(255, 10, 0, 89);
const Color maizeBusYellow = Color.fromARGB(255, 241, 194, 50);
const Color maizeBusBlue = Color.fromARGB(255, 11, 83, 148);

//data types
class Location {
  final String name;
  final String abbrev;
  final List<String> aliases;

  final String? stopId;
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
