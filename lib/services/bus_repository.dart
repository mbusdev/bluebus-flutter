import 'dart:async';
import '../bluebus_api.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';

// Gets the routes and buses from the api
class BusRepository {
  List<BusRouteLine> _routes = [];
  List<Bus> _buses = [];
  Timer? _busUpdateTimer;
  final Duration busUpdateInterval;

  BusRepository({this.busUpdateInterval = const Duration(seconds: 5)});

  Future<List<BusRouteLine>> fetchRoutes() async {
    _routes = await BlueBusApi.fetchRoutes();
    return _routes;
  }

  Future<List<Bus>> fetchBuses() async {
    _buses = await BlueBusApi.fetchBuses();
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
} 