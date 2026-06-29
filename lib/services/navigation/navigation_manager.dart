import 'dart:ui';

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart' show BusStop;
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;



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

  List<Marker> getMarkers() {
    return [];
  }

  List<Polyline> getPolylines() {
    return [];
  }

  Color getColor() {
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
class Walking extends NavigationStage {
  List<LatLng> points = [ //dummy pts taken from google maps by the cctc (replace later)
    const LatLng(42.27792397921826, -83.73596985653457),
    const LatLng(42.27756042901099, -83.7359661838265),
    const LatLng(42.27754197988967, -83.73706331473826),
    const LatLng(42.2775215703816,  -83.73809993417933),
    const LatLng(42.278481544159916, -83.73811396072821),
  ];

  LatLng? currWalkingPos = const LatLng(42.27831772684626, -83.73599054149456); //near cctc (replace w user's location)

  int _nextIndex = 0;
  static const double _reachThresholdMeters = 15.0;

  double _distMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
        math.cos(b.latitude * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * R * math.asin(math.sqrt(s));
  }

  double _bearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  //call this whenever a new gps fix arrives, returns true if a waypoint was just cleared (so the ui can refresh)
  bool updatePosition(LatLng newPos) {
    currWalkingPos = newPos;
    if (_nextIndex < points.length &&
        _distMeters(newPos, points[_nextIndex]) <= _reachThresholdMeters) {
      _nextIndex++;
      return true;
    }
    return false;
  }

  @override
  String getTitle() {
    if (_nextIndex >= points.length) {
      return "You've arrived!";
    }
    final pos = currWalkingPos;
    if (pos == null) {
      return "Acquiring GPS…";
    }
    final feet = (_distMeters(pos, points[_nextIndex]) * 3.28084).round();
    return "${_directionWord(pos)} in $feet ft";
  }

  @override
  String getSubtitle() {
    if (_nextIndex >= points.length) {
      return "Walk complete";
    }
    return "Waypoint ${_nextIndex + 1} of ${points.length}";
  }

  String _directionWord(LatLng pos) {
    if (_nextIndex == 0) {
      return "Head";
    }
    final incoming = _bearing(points[_nextIndex - 1], pos);
    final outgoing = _bearing(pos, points[_nextIndex]);
    final diff = (outgoing - incoming + 360) % 360;
    if (diff < 20 || diff > 340) {
      return "Continue straight";
    }
    if (diff <= 170) {
      return "Turn right";
    }
    if (diff >= 190) {
      return "Turn left";
    }
    return "U-turn";
  }
}


class DemoStage extends NavigationStage {

  String getTitle() {
    return "This is a demo! #$favoriteNumber";
  }

  String getSubtitle() {
    return "Look, here's a subtitle too #$favoriteNumber";
  }

  double length = 15.0;
  double percent_complete = 0.110;

  LatLng startPoint;
  LatLng endPoint;

  double favoriteNumber;

  DemoStage({
    required this.favoriteNumber,
    required this.length,
    required this.percent_complete,
    required this.startPoint,
    required this.endPoint
  });

  @override
  Color getColor() { // Return a random color
    // return Color(this.favoriteNumber.hashCode | 0xFF000000); // Return a color derived from this.favoriteNumber
    const double golden = 0.618033988749895;
    final double hue = ((this.favoriteNumber.hashCode * golden) % 1.0).abs() * 360;
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.55).toColor();
  }

  @override
  List<Marker> getMarkers() {
    return [
      Marker(
        markerId: MarkerId("${this.favoriteNumber}-${this.startPoint.latitude}-${this.startPoint.longitude}"),
        position: this.startPoint
      ),
      Marker(
        markerId: MarkerId("${this.favoriteNumber}-${this.endPoint.latitude}-${this.endPoint.longitude}"),
        position: this.endPoint
      )
    ];
  }
  @override
  List<Polyline> getPolylines() {
    return [
      Polyline(
        polylineId: PolylineId("${this.favoriteNumber}-${this.startPoint.latitude}-${this.startPoint.longitude}"),
        points: [
          this.startPoint,
          this.endPoint
        ],
        color: this.getColor()
      )
    ];
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
          favoriteNumber: 1,
          length: 15,
          percent_complete: 0.80,
          startPoint: LatLng(42.281973, -83.765719),
          endPoint: LatLng(42.281291, -83.743918)
        ),
        DemoStage(
          favoriteNumber: 2,
          length: 33,
          percent_complete: 0.23,
          startPoint: LatLng(42.281291, -83.743918),
          endPoint: LatLng(42.287031, -83.743532),
        ),
        DemoStage(
          favoriteNumber: 3,
          length: 4,
          percent_complete: 0.0,
          startPoint: LatLng(42.287031, -83.743532),
          endPoint: LatLng(42.289689, -83.738435)
        ),
      
      ]; // Stores all the states for users to page back and forth
  NavigationLayer? mapLayer;

  void setMapLayer(NavigationLayer mapLayer_in) {
    this.mapLayer = mapLayer_in;
    rebuildMarkersAndPolylines();
  }

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
    rebuildMarkersAndPolylines();
  }

  // Some sort of code to read the current stage and next stage to determine whether the user can "jump" (stage switch)
  //    Look at the bus times of the next stage and the walking position of the current stage to determine if the user is A) near the end of their walking path and B) the bus hasn't left yet
  // Write a function to detect if the stage switch went wrong
  //    Allen: Add UI to ask the user about which new bus to take [Check with Ishan and Harvey]
  //      Isaac: I'll talk to Ishan (gc with Allen+Ishan+Harvey) about what the final logic is for the "Oops" stage

  void rebuildMarkersAndPolylines() { // Call this whenever markers or polylines change
    if (this.mapLayer == null) {
      debugPrint("Warning: Tried to rebuild markers and polylines but no map layer was registered with NavigationManager!");
      return;
    }
    Set<Marker> markersToDisplay = stageList.expand((NavigationStage stage) => stage.getMarkers()).toSet();
    Set<Polyline> polylinesToDisplay = stageList.expand((NavigationStage stage) => stage.getPolylines()).toSet();

    this.mapLayer!.setMarkers(markersToDisplay);
    this.mapLayer!.setPolylines(polylinesToDisplay);
    this.mapLayer!.reload();

    // FUTURE TODO: Get some sample data for polylines/markers and conditionally show them on the map--define a "navigation mode" that can be active (or not) in map_screen.dart
    
  }

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
