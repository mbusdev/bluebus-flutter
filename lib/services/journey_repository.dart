import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/journey.dart';

class JourneyRepository {
  static Future<List<Journey>> planJourney({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    try {
      final response = await backendClient.getMbusApiV3PlanJourney(
        originLat: originLat,
        originLon: originLon,
        destLat: destLat,
        destLon: destLon,
      );
      return response.journeys.map(Journey.fromBackend).toList();
    } on DioException catch (e) {
      final res = e.response;
      if (res != null && res.statusCode != 200) {
        throw Exception('Failed to plan journey: status ${res.statusCode}');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}