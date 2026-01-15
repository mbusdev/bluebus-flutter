import 'dart:convert';
import 'package:bluebus/constants.dart';
import 'package:http/http.dart' as http;
import '../models/bus_stop.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

// for busses
Future<List<BusStopWithPrediction>> fetchNextBusStops(String busID) async {
  Uri url;

  if (int.tryParse(busID) != null) {
    // busID is numeric, so it's a ride bus
    url = Uri.parse("$BACKEND_URL/getRidePredictions/$busID");
  } else {
    // otherwise, it's a michigan bus
    url = Uri.parse("$BACKEND_URL/getBusPredictions/$busID");
  }

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    final List<dynamic> predictions = data['bustime-response']['prd'];
    return predictions.map((json) => BusStopWithPrediction.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load bus stops');
  }
}

// for bus stops
Future<(List<BusWithPrediction>, bool)> fetchStopData(String stopID) async {

  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('favorite_stops') ?? <String>[];
  bool toReturn = list.contains(stopID);

  Uri url;

  if (int.tryParse(stopID) != null) {
    // stopID is numeric, so it's a ride stop
    url = Uri.parse("$BACKEND_URL/getRideStopPredictions/$stopID");
  } else {
    // otherwise, it's a michigan stop
    url = Uri.parse("$BACKEND_URL/getStopPredictions/$stopID");
  }

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    final List<dynamic> predictions = data['bustime-response']['prd'];
    return (predictions.map((json) => BusWithPrediction.fromJson(json)).toList(), toReturn);
  } else {
    throw Exception('Failed to load bus stops');
  }
}
