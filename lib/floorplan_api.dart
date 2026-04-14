import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'models/building_floors.dart';

class FloorPlanApi {
  static const String baseUrl = BACKEND_URL;

  static Future<List<BuildingFloors>> fetchFloorPlans() async {
   final response = await http.get(Uri.parse('$baseUrl/graph?buildingId=dc&floor=1')); //need to modify for specific buildings/floors
   if (response.statusCode != 200) throw Exception('Failed to load floor plans');
   final data = jsonDecode(response.body) as Map<String, dynamic>;
   final floorPlan = BuildingFloors.fromJson(data);
   //could do print(floorPlan); to test
   return [floorPlan];
  }
}