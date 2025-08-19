import 'dart:convert';
import 'package:bluebus/constants.dart';
import 'package:http/http.dart' as http;
import '../models/bus_stop.dart'; 

Future<List<BusStopWithPrediction>> fetchNextBusStops(String busID) async {
  final url = Uri.parse("$BACKEND_URL/getBusPredictions1/$busID");
  
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    final List<dynamic> predictions = data['bustime-response']['prd'];
    return predictions.map((json) => BusStopWithPrediction.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load bus stops');
  }
}