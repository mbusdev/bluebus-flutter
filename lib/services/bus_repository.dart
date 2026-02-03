import 'dart:async';
import 'package:flutter/material.dart';

import '../bluebus_api.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';

// Gets the routes and buses from the api
class BusRepository {
  List<BusRouteLine> _routes = [];
  static List<Bus> _buses = [];
  Timer? _busUpdateTimer;
  final Duration busUpdateInterval;
  int busDataVersion = 0; // Used to prevent duplicates--i.e. whatever calls BusProvider can figure out if BusProvider has new data to give it by keeping its own copy of busDataVersion and checking to see if it has been incremented.

  BusRepository({this.busUpdateInterval = const Duration(seconds: 5)});

  Future<List<BusRouteLine>> fetchRoutes() async {
    _routes = await BlueBusApi.fetchRoutes();
    return _routes;
  }

  Future<List<Bus>> fetchBuses() async {
    _buses = await BlueBusApi.fetchBuses();
    busDataVersion++;
    return _buses;
  }

  void startBusUpdates(void Function(List<Bus>) onUpdate) {
    _busUpdateTimer?.cancel();
    _busUpdateTimer = Timer.periodic(busUpdateInterval, (_) async {
      final buses = await fetchBuses();
      onUpdate(buses);
    });
  }

  // void forceBusUpdate(void Function(List<Bus>) onUpdate) {

  // }

  void stopBusUpdates() {
    _busUpdateTimer?.cancel();
  }

  void dispose() {
    stopBusUpdates();
  }

  static Bus? getBus(String busID){
    for (Bus b in _buses){
      if (b.id == busID){
        // debugPrint("***** FOUND BUS WITH BUS ID ${busID}, routeId: ${b.routeId}");
        return b;
      }
    }
    return null;
  }
} 