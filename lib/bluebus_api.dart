import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'constants.dart';
import 'models/bus_stop.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';

class BlueBusApi {
  static const String baseUrl = BACKEND_URL;

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes() async {
    final response = await http.get(Uri.parse('$baseUrl/getAllRoutes'));
    if (response.statusCode != 200) throw Exception('Failed to load routes');
    final data = jsonDecode(response.body);
    final routes = <BusRouteLine>[];
    final routeJson = data['routes'] as Map<String, dynamic>;
    routeJson.forEach((routeId, subroutes) {
      for (final subroute in subroutes) {
        final points = <LatLng>[];
        final stops = <BusStop>[];
        for (final point in subroute['pt']) {
          points.add(LatLng(point['lat']?.toDouble() ?? 0, point['lon']?.toDouble() ?? 0));
          if (point['typ'] == 'S') {
            stops.add(BusStop.fromJson(point, routeId));
          }
        }
        routes.add(BusRouteLine(routeId: routeId, points: points, stops: stops));
        // Handle detour points if present
        if (subroute.containsKey('dtrpt')) {
          final detourPoints = <LatLng>[];
          final detourStops = <BusStop>[];
          for (final point in subroute['dtrpt']) {
            detourPoints.add(LatLng(point['lat']?.toDouble() ?? 0, point['lon']?.toDouble() ?? 0));
            if (point['typ'] == 'S') {
              detourStops.add(BusStop.fromJson(point, routeId));
            }
          }
          routes.add(BusRouteLine(routeId: routeId, points: detourPoints, stops: detourStops));
        }
      }
    });
    return routes;
  }

  // Fetch all buses and their positions
  static Future<List<Bus>> fetchBuses() async {
    final response = await http.get(Uri.parse('$baseUrl/getVehiclePositions'));
    if (response.statusCode != 200) throw Exception('Failed to load buses');
    final data = jsonDecode(response.body);
    final buses = <Bus>[];
    final busJson = data['buses'] as List<dynamic>?;
    if (busJson != null) {
      for (final bus in busJson) {
        buses.add(Bus.fromJson(bus));
      }
    }
    return buses;
  }
}