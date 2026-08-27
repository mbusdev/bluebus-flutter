import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';
import 'services/route_color_service.dart';

class BlueBusApi {
  static const String baseUrl = BACKEND_URL;

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes(Function(String route, String error) onError) async {
    try {
      final routes = await backendClient.getApiV4AllMbusRoutes();
      await RouteColorService.initialize();

      return routes
        .map((r) {
          final routeColor = RouteColorService.getRouteColor(r.routeId);
          final routeImageUrl = RouteColorService.getRouteImageUrl(r.routeId);

          return BusRouteLine.fromBackend(r, routeColor, routeImageUrl);
        })
        .toList();
    } on DioException catch (e) {
      final res = e.response;

      if (res != null && res.statusCode != 200) {
        onError("", "Failed to load routes");
        throw Exception('Failed to load routes');
      }
      onError("", e.message ?? e.toString());
      rethrow;
    } catch (e) {
      onError("", e.toString());
      rethrow;
    }
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
