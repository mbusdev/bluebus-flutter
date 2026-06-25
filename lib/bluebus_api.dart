import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'constants.dart';
import 'models/bus_stop.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';
import 'services/route_color_service.dart';
import 'utils/geometry.dart';

class BlueBusApi {
  static const String baseUrl = BACKEND_URL;

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes(Function(String route, String error) onError) async {
    final response = await http.get(Uri.parse('$baseUrl/getAllRoutes'));
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
            final isLast = i == pointList.length - 1; // bool to check if last
            points.add(
              LatLng(
                point['lat']?.toDouble() ?? 0,
                point['lon']?.toDouble() ?? 0,
              ),
            );
            if (point['typ'] == 'S') {
              // get rotation of stop
              if (isLast){
                // use the previous 2 points to calculate rotation
                double stopRotation = pointRotation(
                  pointList[i - 2]['lat']?.toDouble() ?? 0,
                  pointList[i - 2]['lon']?.toDouble() ?? 0,
                  pointList[i - 1]['lat']?.toDouble() ?? 0,
                  pointList[i - 1]['lon']?.toDouble() ?? 0,
                );
                stops.add(BusStop.fromJson(point, routeId, stopRotation, false));
                
              } else {
                // use the next 2 points to calculate rotation
                double stopRotation = pointRotation(
                  pointList[i + 1]['lat']?.toDouble() ?? 0,
                  pointList[i + 1]['lon']?.toDouble() ?? 0,
                  pointList[i + 2]['lat']?.toDouble() ?? 0,
                  pointList[i + 2]['lon']?.toDouble() ?? 0,
                );
                stops.add(BusStop.fromJson(point, routeId, stopRotation, false));
              }

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

          // Handle detour points if present
          if (subroute.containsKey('dtrpt')) {
            final detourPoints = <LatLng>[];
            final detourStops = <BusStop>[];

            // Cast to list to be able to be able to get different elements
            final detourPointList = subroute['dtrpt'] as List; 

            for (int i = 0; i < detourPointList.length; i++) {
              final point = detourPointList[i];
              final isLast = i == detourPointList.length - 1; // bool to check if last

              detourPoints.add(
                LatLng(
                  point['lat']?.toDouble() ?? 0,
                  point['lon']?.toDouble() ?? 0,
                ),
              );
              if (point['typ'] == 'S') {
                // get rotation of stop
                if (isLast){
                  // use the previous 2 points to calculate rotation
                  double stopRotation = pointRotation(
                    detourPointList[i - 2]['lat']?.toDouble() ?? 0,
                    detourPointList[i - 2]['lon']?.toDouble() ?? 0,
                    detourPointList[i - 1]['lat']?.toDouble() ?? 0,
                    detourPointList[i - 1]['lon']?.toDouble() ?? 0,
                  );
                  detourStops.add(BusStop.fromJson(point, routeId, stopRotation, false));
                  
                } else {
                  // use the next 2 points to calculate rotation
                  double stopRotation = pointRotation(
                    detourPointList[i + 1]['lat']?.toDouble() ?? 0,
                    detourPointList[i + 1]['lon']?.toDouble() ?? 0,
                    detourPointList[i + 2]['lat']?.toDouble() ?? 0,
                    detourPointList[i + 2]['lon']?.toDouble() ?? 0,
                  );
                  detourStops.add(BusStop.fromJson(point, routeId, stopRotation, false));
                }
              }
            }

            routes.add(
              BusRouteLine(
                routeId: routeId,
                points: detourPoints,
                stops: detourStops,
                color: routeColor,
                imageUrl: routeImageUrl,
              ),
            );
          }
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
      final response = await http.get(
        Uri.parse('$baseUrl/getVehiclePositions'),
      );
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
    } catch (e) {
      // on error return a blank list
      return [];
    }
  }
}

// TODO: Make bus routes have better fallback, so if one route fails to be processed it doesn't tank the rest of them
