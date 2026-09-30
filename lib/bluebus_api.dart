import 'dart:convert';
import 'dart:math' as Math;
import 'package:bluebus/services/bus_repository.dart';
import 'package:flutter/cupertino.dart';
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

    BusRepository.writeToCache('bluebus-routes-cache-v${await AppInfo.version()}', response.body);

    return processRoutesJson(response.body, onError);
  }

  // static Future<List<BusRouteLine>> fetchRoutesWithCache(Function(String route, String error) onError) async {
  //   String? cachedRoutes = await BusRepository.getFromCache('bluebuscache-v${await AppInfo.version()}');

  //   if (cachedRoutes == null) {
  //     return fetchRoutes(onError)
  //   }

  //   TODO: Right now we have a return statement that processes the updated routes, but that won't work since we return the routes TWICE--once when we load from cache and a second time when the web request goes through. Make sure the app reflects the changes when the real web request goes through, not just when the cache returns a result. Also finish this function and add another version into theride_api.dart as well
  // }

  static Future<List<BusRouteLine>> processRoutesJson(String jsonBody, Function(String route, String error) onError) async {
    final data = jsonDecode(jsonBody);
    final routes = <BusRouteLine>[];
    final routeJson = data['routes'] as Map<String, dynamic>;

    await RouteColorService.initialize();

    routeJson.forEach((routeId, subroutes) {
      for (final subroute in subroutes) {
        try {
          final points = <LatLng>[];
          final stops = <(int, BusStop)>[];
          
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
              List<LatLng> latLngPoints = pointList.map((dynamic stop_json) {
                return LatLng(stop_json["lat"], stop_json["lon"]);
              }).toList();
              final stopRotation = routeStopRotation(latLngPoints, i);
              stops.add((i, BusStop.fromJson(point, routeId, stopRotation, false)));
            }
          }

          // Get route color and image
          final routeColor = RouteColorService.getRouteColor(routeId);
          final routeImageUrl = RouteColorService.getRouteImageUrl(routeId);

          // if (subroute.containsKey('dtrpt')) {
            // Only show the main route if there is no detour
            routes.add(
              BusRouteLine(
                routeId: routeId,
                points: points,
                stops: stops,
                color: routeColor,
                imageUrl: routeImageUrl,
              ),
            );
          // }

          // Handle detour points if present
          // if (!subroute.containsKey('dtrpt')) {
          //   final detourPoints = <LatLng>[];
          //   final detourStops = <(int, BusStop)>[];

          //   // Cast to list to be able to be able to get different elements
         //   final detourPointList = subroute['dtrpt'] as List; 

            // for (int i = 0; i < detourPointList.length; i++) {
            //   final point = detourPointList[i];
            //   detourPoints.add(
            //     LatLng(
            //       point['lat']?.toDouble() ?? 0,
            //       point['lon']?.toDouble() ?? 0,
            //     ),
            //   );
            //   if (point['typ'] == 'S') {
            //     final stopRotation = routeStopRotation(detourPointList, i);
            //     detourStops.add((i, BusStop.fromJson(point, routeId, stopRotation, false)));
            //   }
            // }

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
