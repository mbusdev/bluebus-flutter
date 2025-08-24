import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/journey.dart';

class JourneyRepository {
  static Future<List<Journey>> planJourney({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    final uri = Uri.parse('$BACKEND_URL/plan-journey').replace(queryParameters: {
      'originLat': originLat.toString(),
      'originLon': originLon.toString(),
      'destLat': destLat.toString(),
      'destLon': destLon.toString(),
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to plan journey: status ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data == null || data['journeys'] == null) {
      throw Exception('No journeys found in response');
    }
    return (data['journeys'] as List).map((e) => Journey.fromJson(e)).toList();
  }
}