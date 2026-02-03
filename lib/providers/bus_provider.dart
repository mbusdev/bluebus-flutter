import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
import '../services/bus_repository.dart';

class BusProvider extends ChangeNotifier {
  final BusRepository repository;

  // NEXT STEPS TODO: Figure out why these buses are staying in the same place!!

  List<BusRouteLine> _routes = [];
  List<Bus> _buses = [];
  Map<String, Bus> _busMap = {};
  List<Bus> changed_buses = [];
  List<Bus> new_buses = [];
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
      debugPrint("Got loadBuses() call");
      List<Bus> new_buses = await repository.fetchBuses();
      
      identifyChangedBuses(new_buses);

      // TODO: Once the _changed_buses are identified, figure out where the listeners are. In the map_widget, go through the _changed_buses and _new_buses and update accordingly
      // The repository might be communicating directly with listeners, bypassing

      _buses = new_buses;
      _busMap = convertToMap(new_buses);
      notifyListeners();
      
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Map<String,Bus> convertToMap(List<Bus> buses_list) {
    Map<String,Bus> tmp_map = {};
    for (Bus b in buses_list) {
      tmp_map[b.id] = b;
    }
    return tmp_map;
  }

  void identifyChangedBuses(List<Bus> allNewBuses) {
    // Identifies the buses that differ in location/heading versus the last scan
    // This function requires that _busMap be processed (or empty if it's the first bus response)
    changed_buses.clear();
    new_buses.clear();

    // TODO: Figure out why new_buses is 0 and changed_buses is 0

    for (Bus newBus in allNewBuses) {
      if (_busMap.containsKey(newBus.id)) {
        Bus existingBus = _busMap[newBus.id]!;
        if (newBus.position != existingBus.position ||
            newBus.heading != existingBus.heading) {
          changed_buses.add(newBus);
        }
      } else {
        new_buses.add(newBus);
        // _changed_buses.add(newBus); //TODO: Do we need to have some _added_buses list that keeps the new buses not seen in previous lists?
      }
      // for (Bus existingBus in _buses) {
      //   if (newBus.id == existingBus.id) {
      //     if (newBus.position != existingBus.position ||
      //         newBus.heading != existingBus.heading) { // Note: This currently does not check fullness
      //       _changed_buses.add(newBus);
      //     }
      //     break;
      //   }
      // }
    }
  }

  void startBusUpdates() {
    repository.startBusUpdates((buses) { // Automatic bus updates go through this callback
      _buses = buses;
      identifyChangedBuses(buses);
      notifyListeners();
    });
  }

  void forceBusUpdate() { // Exactly the same as startBusUpdates--maybe merge these?
    debugPrint("Forcing bus update...");
    repository.startBusUpdates((buses) {
      _buses = buses;
      identifyChangedBuses(buses);
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
    super.dispose();
  }
} 