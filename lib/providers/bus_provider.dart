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

  BusProvider({required this.repository});

  Future<void> loadRoutes() async {
    try {
      _routes = await repository.fetchRoutes();
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

  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }
} 