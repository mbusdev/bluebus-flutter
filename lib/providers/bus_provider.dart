import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
import '../services/bus_repository.dart';

class BusProvider extends ChangeNotifier {
  final BusRepository repository;

  List<BusRouteLine> _routes = [];
  List<Bus> _buses = [];
  bool _loading = false;
  String? _error;

  List<BusRouteLine> get routes => _routes;
  List<Bus> get buses => _buses;
  bool get loading => _loading;
  String? get error => _error;
  Timer? _timer;

  BusProvider({required this.repository});

  void startRouteUpdates() {
    loadRoutes((String r, String e) { }); // ignore sending any errors after the first call in map_screen.dart

    // reloads every 2 minutes
    _timer = Timer.periodic(const Duration(minutes: 2), (timer) {
      loadRoutes((String r, String e) { });
    });
  }

  Future<void> loadRoutesWithCache(Function(String route, String error) onError) async {
    // Uses the cached value and loads the routes in the background, unless there are no routes cached
    try {
      _routes = await repository.fetchRoutesFromCacheAndHTTP(onError); // This loads from cache or via HTTP if cache isn't present
      
    } catch (e) {
      debugPrint("Routes loading error!!");
      _error = e.toString();
      // let futureBuilder catch the error up in the chain
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
      
      // loadRoutes(onError); // Now load all the routes via HTTP in the background.
      // No need to do this since busProvider.startRouteUpdates() (at the end of _loadAllData) auto-loads routes every 2 minutes
    }
  }

  Future<void> loadRoutes(Function(String route, String error) onError) async {
    try {
      _routes = await repository.fetchRoutes(onError);
    } catch (e) {
      _error = e.toString();
      // let futureBuilder catch the error up in the chain
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadBuses() async {
    try {
      _buses = await repository.fetchBuses();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void startBusUpdates() {
    repository.startBusUpdates((buses) {
      _buses = buses;
      notifyListeners();
    });
  }

  void stopBusUpdates() {
    repository.stopBusUpdates();
  }

  // TODO: Add a checkForBus() method

  bool containsBus(String searchBusId) {
    
    for (int i = 0; i < _buses.length; i++) {
      // debugPrint("Checking ID "+searchBusId + " against "+_buses[i].id);
      if (_buses[i].id == searchBusId) return true;
    }
    return false;
  }


  @override
  void dispose() {
    repository.dispose();
    _timer?.cancel();
    super.dispose();
  }
} 