import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'constants.dart';
import 'models/bus_stop.dart';
import 'models/bus.dart';
import 'models/bus_route_line.dart';
import 'services/route_color_service.dart';

class BlueBusApi {
  static const String baseUrl = BACKEND_URL;

  // Fetch all routes and their polylines/stops
  static Future<List<BusRouteLine>> fetchRoutes() async {
    final response = await http.get(Uri.parse('$baseUrl/getAllRoutes'));
    if (response.statusCode != 200) throw Exception('Failed to load routes');
    final data = jsonDecode(response.body);
    final routes = <BusRouteLine>[];
    final routeJson = data['routes'] as Map<String, dynamic>;

    await RouteColorService.initialize();

    routeJson.forEach((routeId, subroutes) {
      for (final subroute in subroutes) {
        final points = <LatLng>[];
        final stops = <BusStop>[];
        for (final point in subroute['pt']) {
          points.add(
            LatLng(
              point['lat']?.toDouble() ?? 0,
              point['lon']?.toDouble() ?? 0,
            ),
          );
          if (point['typ'] == 'S') {
            stops.add(BusStop.fromJson(point, routeId));
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
          for (final point in subroute['dtrpt']) {
            detourPoints.add(
              LatLng(
                point['lat']?.toDouble() ?? 0,
                point['lon']?.toDouble() ?? 0,
              ),
            );
            if (point['typ'] == 'S') {
              detourStops.add(BusStop.fromJson(point, routeId));
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
  }

  // Fetch upcoming arrivals for a stop id (stpid)
  // Call '{baseUrl}getArrivalsForStop?stpid=<stpid>' from backend
  // which returns a list of arrival stops if there are any.
  // Each arrival object is expected to contain at least: 'rt' (route id) and 'arrivalTime'.
  static Future<List<Map<String, dynamic>>> fetchArrivalsForStop(
    String stpid,
  ) async {
    final uri = Uri.parse('$baseUrl/getArrivalsForStop?stpid=$stpid');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load arrivals for stop $stpid');
    }

    final decoded = jsonDecode(response.body);

    // Normalize to a List<Map>
    List<Map<String, dynamic>> arrivals = [];
    if (decoded is List) {
      arrivals = decoded.cast<Map<String, dynamic>>();
    } else if (decoded is Map && decoded['arrivals'] is List) {
      arrivals = (decoded['arrivals'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      return <Map<String, dynamic>>[];
    }

    // Normalize arrivalTime values: backend may return strings like "20250818 14:40:00".
    final pattern = RegExp(r'^\d{8} \d{2}:\d{2}:\d{2}$');
    for (final a in arrivals) {
      final raw = a['arrivalTime'] ?? a['eta'] ?? a['time'];
      if (raw == null) continue;

      if (raw is String) {
        final s = raw.trim();
        if (pattern.hasMatch(s)) {
          // Convert "YYYYMMDD HH:MM:SS" -> "YYYY-MM-DD HH:MM:SS" then parse
          try {
            // Use 'T' separator to produce an ISO-like string that DateTime.parse accepts
            final isoLike =
                '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}T${s.substring(9)}';
            final dt = DateTime.parse(isoLike);
            a['arrivalTime'] = dt.millisecondsSinceEpoch;
          } catch (e) {
            // leave original string if parsing fails
            a['arrivalTime'] = s;
          }
        } else {
          // Try to parse numeric strings
          final parsed = int.tryParse(s);
          if (parsed != null) {
            a['arrivalTime'] = parsed;
          } else {
            a['arrivalTime'] = s;
          }
        }
      } else if (raw is int) {
        a['arrivalTime'] = raw;
      } else if (raw is double) {
        a['arrivalTime'] = raw.toInt();
      }
    }

    return arrivals;
  }
}
