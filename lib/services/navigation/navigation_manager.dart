import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_stop.dart';



sealed class NavigationStage {
  String title = "...";
}

// class NavWalking extends NavigationStage {
//   // ...
// }

// class NavOnBus extends NavigationStage {
//   // ...
// }

class ChooseBus extends NavigationStage{
  @override title = "Choose a Bus";
  //Not sure if we actually need this. Depends on if we want to filter out some buses from certain stops. 
  List<Bus> potentialBuses = [];
  List<BusStop> potentialStops = [];

  //TODO function that returns what it should say in the bubble (title and subtitle)
  // If you have a list of buses to board and stops, 
  // this can help you display a bus and the stop you will board
  // This could be simplified more, probably by picking up data from another function 
//   String getTitle() returns the title displayed in the big blue box
// String getSubtitle() returns the subtitle displayed in the big blue box
// double length is the length (in minutes) of your segment
// double percent_complete
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
