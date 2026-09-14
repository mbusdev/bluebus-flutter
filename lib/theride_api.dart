import 'dart:convert';
import 'dart:math' as Math;
import 'package:bluebus/utils/geometry.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'constants.dart';
import 'models/bus_stop.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';
import 'services/route_color_service.dart';

// Function to calculate rotation angle between two geographical points
// (used for bus stop icon orientation)
double pointRotation(double lat1, double lon1, double lat2, double lon2) {
  const double degToRad = 0.017453292519943295; // π / 180
  const double radToDeg = 57.29577951308232;    // 180 / π

  double dLat = lat2 - lat1;
  double dLon = lon2 - lon1;

  // Scale longitude by cos(lat) to correct for east-west distance
  double x = dLon * (Math.cos(lat1 * degToRad));
  double y = dLat;

  double angle = Math.atan2(x, y) * radToDeg;

  // Normalize to [0, 360)
  if (angle < 0) angle += 360;

  return angle;
}

class RideAPI {
  static const String baseUrl = BACKEND_URL;

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes(Function(String route, String error) onError) async {
    final response = await http.get(Uri.parse('$baseUrl/getAllRideRoutes'));
    if (response.statusCode != 200) throw Exception('Failed to load routes');
    final data = jsonDecode(response.body);
    final routes = <BusRouteLine>[];
    final routeJson = data['routes'] as Map<String, dynamic>;

    await RouteColorService.initialize();

    routeJson.forEach((routeId, subroutes) {
      for (final subroute in subroutes) {
        try {
          final points = <LatLng>[];
          final stops = <BusStop>[];
          
          // Cast to list to be able to be able to get different elements
          final pointList = subroute['pt'] as List; 

          for (int i = 0; i < pointList.length; i++) {
            final point = pointList[i];
            points.add(
              LatLng(
                point['lat']?.toDouble() ?? 0,
                point['lon']?.toDouble() ?? 0,
              ),
            );
            if (point['typ'] == 'S') {
              // get rotation of stop
              final stopRotation = routeStopRotation(pointList, i);
              stops.add(BusStop.fromJson(point, routeId, stopRotation, true));

            }
          }

          // Get route color and image
          final routeColor = RouteColorService.getRouteColor(routeId);
          final routeImageUrl = RouteColorService.getRouteImageUrl(routeId);

          routes.add(
            BusRouteLine(
              routeId: routeId,
              points: points,
              stops: stops,
              color: routeColor,
              imageUrl: routeImageUrl,
            ),
          );

          // Commented out: On a route with a detour, 'dtrpt' contains the *original* route. While we wait on a more permanent future solution to display detours correctly, this is here just to reduce confusion by only showing the bus's actual (detoured) route.
          // Handle detour points if present
          // if (subroute.containsKey('dtrpt')) {
          //   final detourPoints = <LatLng>[];
          //   final detourStops = <BusStop>[];

          //   // Cast to list to be able to be able to get different elements
          //   final detourPointList = subroute['dtrpt'] as List; 

          //   for (int i = 0; i < detourPointList.length; i++) {
          //     final point = detourPointList[i];

          //     detourPoints.add(
          //       LatLng(
          //         point['lat']?.toDouble() ?? 0,
          //         point['lon']?.toDouble() ?? 0,
          //       ),
          //     );
          //     if (point['typ'] == 'S') {
          //       // get rotation of stop
          //       final stopRotation = routeStopRotation(detourPointList, i);
          //       detourStops.add(BusStop.fromJson(point, routeId, stopRotation, true));
          //     }
          //   }

          //   routes.add(
          //     BusRouteLine(
          //       routeId: routeId,
          //       points: detourPoints,
          //       stops: detourStops,
          //       color: routeColor,
          //       imageUrl: routeImageUrl,
          //     ),
          //   );
          // }
        } catch (e) {
          onError(routeId, e.toString());
        }
      }
    });
    return routes;
  }

  // Fetch all buses and their positions
  static Future<List<Bus>> fetchBuses() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/getRidePositions'));
      if (response.statusCode != 200) throw Exception('Failed to load buses');
      final data = jsonDecode(response.body);
      final buses = <Bus>[];
      final busJson = data['buses'] as List<dynamic>?;

      await RouteColorService.initialize();

      if (busJson != null) {
        for (final bus in busJson) {
          final routeId = bus['rt'] ?? '';
          final routeColor = RouteColorService.getRouteColor(routeId);
          final routeImageUrl = RouteColorService.getRouteImageUrl(routeId);

          buses.add(
            Bus.fromJson(
              bus,
              routeColor: routeColor,
              routeImageUrl: routeImageUrl,
            ),
          );
        }
      }

      return buses;
    } catch (e){

      // on error return a blank list
      return [];
    }
  }
}
