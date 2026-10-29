import 'dart:convert';
import 'package:bluebus/services/bus_repository.dart';
import 'package:bluebus/backend/export.dart' as backend;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';
import 'services/route_color_service.dart';

class RideAPI {
  static const String baseUrl = BACKEND_URL;
  static final backend.BackendClient _client = backend.BackendClient(Dio(BaseOptions(baseUrl: backendOpenApiUrl)));

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes(Function(String route, String error) onError) async {
    try {
      final routes = await _client.getApiV4AllRideRoutes();
      final routesJson = jsonEncode(routes);
      BusRepository.writeToCache('theride-routes-cache-v${await AppInfo.version()}', jsonEncode(routes));
      
      return processRoutesJson(routesJson, onError);
    } on DioException catch (_) {
      onError('', 'Failed to load routes');
      throw Exception('Failed to load routes');
    }
  }

  static Future<List<BusRouteLine>> processRoutesJson(String json, Function(String route, String error) onError) async {
    try {
      final routes = (jsonDecode(json) as List<dynamic>)
        .map((x) => backend.BusRouteLine.fromJson(x));
      await RouteColorService.initialize();

      return routes
        .map((r) {
          final routeColor = RouteColorService.getRouteColor(r.routeId);
          final routeImageUrl = RouteColorService.getRouteImageUrl(r.routeId);

          return BusRouteLine.fromBackend(r, routeColor, routeImageUrl);
        })
        .toList();
    } catch (e) {
        onError("", "Failed to load routes");
        rethrow;
      }
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
