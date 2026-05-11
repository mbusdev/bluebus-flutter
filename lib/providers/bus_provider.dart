import 'dart:async';
import 'package:flutter/material.dart';
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