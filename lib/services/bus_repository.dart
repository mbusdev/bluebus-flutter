import 'dart:async';
import 'package:flutter/material.dart';

import '../bluebus_api.dart';
import '../theride_api.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';

class BusRepository {
  List<BusRouteLine> _routes = [];
  static List<Bus> _buses = [];
  Timer? _busUpdateTimer;
  final Duration busUpdateInterval;

  BusRepository({this.busUpdateInterval = const Duration(seconds: 5)});

  Future<List<BusRouteLine>> fetchRoutes() async {
    // fetching the ride and bluebus routes simultaneously
    final results = await Future.wait([
      BlueBusApi.fetchRoutes(),
      RideAPI.fetchRoutes(), 
    ]);

    // merging both route lists
    _routes = results.expand((routes) => routes).toList();
    return _routes;
  }

  Future<List<Bus>> fetchBuses() async {
    // fetching the ride and bluebus buses simultaneously
    final results = await Future.wait([
      BlueBusApi.fetchBuses(),
      RideAPI.fetchBuses(),
    ]);

    // merging both bus lists
    _buses = results.expand((buses) => buses).toList();
    return _buses;
  }

  void startBusUpdates(void Function(List<Bus>) onUpdate) {
    _busUpdateTimer?.cancel();
    _busUpdateTimer = Timer.periodic(busUpdateInterval, (_) async {
      final buses = await fetchBuses(); 
      onUpdate(buses);
    });
  }

  void stopBusUpdates() {
    _busUpdateTimer?.cancel();
  }

  void dispose() {
    stopBusUpdates();
  }

  static Bus? getBus(String busID){
    for (Bus b in _buses){
      if (b.id == busID){
        return b;
      }
    }
    return null;
  }
}