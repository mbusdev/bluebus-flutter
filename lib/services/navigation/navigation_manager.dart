import 'dart:math';
import 'dart:ui';

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart' show BusStop;
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LineType { Dotted, Dashed}

class NavigationStageStep {
  String getTitle() {
    return "";
  }

  String? getSubtitle() {
    return null; // Return null if no subtitle
  }

  String getTime() {
    return "0:00"; // Get the time
  }

  Color? getColor() {
    return null; // Return null for neutral gray
  }

  LineType getLineType() {
    return LineType.Dashed;
  }

}

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
  
  List<NavigationStageStep> getSteps() {
    return []; // Get navigation stage steps
  }
  List<Marker> getMarkers() {
    return [];
  }
  List<Polyline> getPolylines() {
    return [];
  }

  Color getColor() { // Return a random color
    return Color(0xFFDBE4ED);
  }
}

class NavWalking extends NavigationStage {
  // ...
}

class NavOnBus extends NavigationStage {
  String title = "On Bus";

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
  String title = "Choose a Bus";
  //Not sure if we actually need this. Depends on if we want to filter out some buses from certain stops. 
  List<Bus> potentialBuses = [];
  List<BusStop> potentialStops = [];
  // If you have a list of buses to board and stops, 
  // this can help you display a bus and the stop you will board
  // This could be simplified more, probably by picking up data from another function 
}

//I believe this is just NavWalking but I'm doing it here to be sure. 
class Walking extends NavigationStage{
  //Points in order, you can check if you are near a point to remove it from the route or start another leg
  List<LatLng> points = [];
  //This could be refreshed in intervals
  LatLng? currWalkingPos;


}


class DemoStage extends NavigationStage {

  int favoriteNumber;

  String getTitle() {
    return "This is a demo! #${favoriteNumber}";
  }

  String getSubtitle() {
    return "Look, here's a subtitle too #${favoriteNumber}";
  }

  double length = 15.0;
  double percent_complete = 0.110;

  DemoStage({
    required this.favoriteNumber,
    required this.length,
    required this.percent_complete
  });

  Color getColor() { // Return a random color
    return Color(Random().nextInt(0xFFFFFFFF)).withAlpha(255);
  }

}

class TimelineStep { 
  double estimated_time;
  double percentage;
  Color color;

  TimelineStep({
    required this.estimated_time,
    required this.percentage, // Percentage of the entire progress bar occupied by this timeline step
    required this.color
  });
}

class TimelineInfo {
  List<TimelineStep> timelineSteps = [];
  double activePositionPercentage = 0.0; // e.g. if the user is 31% of the way through the whole trip, this equals 0.31
  TimelineInfo({
    List<TimelineStep>? timelineSteps,
    this.activePositionPercentage = 0.0
  }) : timelineSteps = timelineSteps ?? [];

}

class NavigationManager {
  // TODO: Implement ChangeNotifier and learn how that works

  int currentStage = 0; // Stores the current navigation state index
  List<NavigationStage> stageList =
      [
        DemoStage(
          favoriteNumber: 1, length: 15, percent_complete: 0.80,
        ),
        DemoStage(
          favoriteNumber: 2, length: 33, percent_complete: 0.23,
        ),
        DemoStage(
          favoriteNumber: 3, length: 4, percent_complete: 0.0,
        ),
      
      ]; // Stores all the states for users to page back and forth
  NavigationLayer? mapLayer;

  TimelineInfo getTimeline() {

    // TODO: Also return the user's position in the whole journey
    
    double total_estimated_time = 0.0;
    double activePositionTime = 0.0; // This is the active position percentage before dividing by total estimated trip length
    double activePositionPercentage = 0.0;

    for (int i = 0; i < stageList.length; i++) {

      double currentStageLength = stageList[i].length;

      total_estimated_time += currentStageLength;

      if (i < currentStage) {
        activePositionTime = activePositionTime + currentStageLength;
      } else if (i == currentStage) {
        activePositionTime += currentStageLength * stageList[i].percent_complete;
      }
      
    }
    activePositionPercentage = activePositionTime / total_estimated_time;

    List<TimelineStep> timelineSteps = [];

    for (int i = 0; i < stageList.length; i++) {
      timelineSteps.add(TimelineStep(
        estimated_time: stageList[i].length,
        percentage: stageList[i].length / total_estimated_time,
        color: stageList[i].getColor()
        // TODO: Define a color for the stage in the stage itself
        // color: Colors.red
        )
      );
    }

    return TimelineInfo(timelineSteps: timelineSteps, activePositionPercentage: activePositionPercentage);

  }

  // Some way for the navigation widget to

  void init() {
    // Init as necessary
  }

  // Some sort of code to read the current stage and next stage to determine whether the user can "jump" (stage switch)
  //    Look at the bus times of the next stage and the walking position of the current stage to determine if the user is A) near the end of their walking path and B) the bus hasn't left yet
  // Write a function to detect if the stage switch went wrong
  //    Allen: Add UI to ask the user about which new bus to take [Check with Ishan and Harvey]
  //      Isaac: I'll talk to Ishan (gc with Allen+Ishan+Harvey) about what the final logic is for the "Oops" stage

  NavigationStage getCurrentStage() {
    return stageList[currentStage];
  }

  void nextStage() {
    currentStage = (currentStage + 1) % stageList.length;
  }
  void previousStage() {
    currentStage = (currentStage - 1) % stageList.length;
  }

  // TODO: Add start()/stop() methods


  // - Allen: Get “Oops” code started. Find a way to talk to the NavigationOverlayWidget
  // - Find a way to get the two to talk to each other: I.e. whenever `NavigationOverlayWidget` is created, it calls a specific method inside NavigationManager that says "Hey, I'm here, please save me in a member variable", so when the "Oops" stage happens later you can call localReferenceToOverlayWidget.displayOopsDialog(...)
  //    The stage (e.g. "On bus") should call the "Oops" stage when it needs to
}
