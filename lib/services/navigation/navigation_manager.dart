import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';



sealed class NavigationStage {
  // String title = "..."; //Don't use this anymore--implement getTitle() instead
  String getTitle() {
    return "Swim forward"; // Title displayed on the big bar at the top
  }

  String getSubtitle() {
    return "Swim for 200 meters"; // Subtitle displayed on the big bar at the top
  }

  double length = 0.0; // Estimated length of your segment, in minutes (i.e. is it a 20-minute walk or 12-minute bus ride?)
  double percent_complete = 0.0; // Estimated completion percentage of your segment (i.e. if you're 32% of the way through your walk)
  
}

class NavWalking extends NavigationStage {
  // ...
}

class NavOnBus extends NavigationStage {
  @override
  String get title => "On Bus";

  String rt;
  String departureStop;
  String arrivalStop;

  Trip trip;
  BusRouteLine? busPath;  

  NavOnBus({
    required this.rt,
    required this.departureStop,
    required this.arrivalStop,
    required this.trip,
    required this.busPath,
  });

  factory NavOnBus.init(Leg leg, Map<String, BusRouteLine> routesCache) {
    final maybeRt = leg.rt;
    final maybeTrip = leg.trip;
    if (maybeRt == null ||
        maybeTrip == null ||
        leg.stopTimes == null ||
        leg.originID == '' ||
        leg.destinationID == '') {
      throw Exception("leg was malformed or not a bus leg");
    }
    return NavOnBus(
      rt: maybeRt,
      departureStop: leg.originID,
      arrivalStop: leg.destinationID,
      trip: maybeTrip,
      busPath: routesCache[maybeRt],
    );
  }
}

class ChooseBus extends NavigationStage{
  title = "Choose a Bus";
  //Not sure if we actually need this. Depends on if we want to filter out some buses from certain stops. 
  List<Bus> potentialBuses;
  List<BusStop> potentialStops;
  // If you have a list of buses to board and stops, 
  // this can help you display a bus and the stop you will board
  // This could be simplified more, probably by picking up data from another function 
}

//I believe this is just NavWalking but I'm doing it here to be sure. 
class Walking extends NavigationStage{
  //Points in order, you can check if you are near a point to remove it from the route or start another leg
  List<LatLng> points;
  //This could be refreshed in intervals
  LatLng currWalkingPos;


}


class NavigationManager {
  // TODO: Implement ChangeNotifier and learn how that works

  int currentStage = 0; // Stores the current navigation state index
  List<NavigationStage> stageList =
      []; // Stores all the states for users to page back and forth
  NavigationLayer? mapLayer;

  // Some way for the navigation widget to

  void init() {
    // Init as necessary
  }

  NavigationStage getCurrentStage() {
    return stageList[currentStage];
  }

  // TODO: Add start()/stop() methods
}
