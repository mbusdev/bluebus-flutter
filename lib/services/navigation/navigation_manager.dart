import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:math' as math;

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart' show BusStop;
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:bluebus/services/route_color_service.dart';
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

  Color getColor() {
    return Color(0xFFDBE4ED);
  }

  final _eventController = StreamController<StageEvent>();

  Stream<StageEvent> get events => _eventController.stream;

  void dispose() {
    _eventController.close();
  }

}

enum RerouteReason {
  wrongBus,
  walkPathChanged
  // Feel free to add additional reasons as necessary
}

sealed class StageEvent {}
class StageComplete extends StageEvent {}
class StageReroute extends StageEvent {
  final RerouteReason reason; // e.g. wrong bus, missed stop
  StageReroute(this.reason);
}

class NavWalking extends NavigationStage {
  // ...
}

class NavOnBus extends NavigationStage {
  String rt;
  String departureStop;
  String arrivalStop;

  Trip trip;
  List<(LatLng, (int, BusStop)?)> busPath;
  // BusRouteLine busPath;  

  NavOnBus({
    required this.rt,
    required this.departureStop,
    required this.arrivalStop,
    required this.trip,
    required this.busPath,
  });

  factory NavOnBus.init(Leg leg, Map<String, List<BusRouteLine>> routesCache) {
    final maybeRt = leg.rt;
    final maybeTrip = leg.trip;
    if (maybeRt == null ||
        maybeTrip == null ||
        leg.stopTimes == null ||
        leg.originID == '' ||
        leg.destinationID == '') {
      throw Exception("leg was malformed or not a bus leg");
    }
    final busLine = determineRouteOfBusLeg(routesCache, maybeRt, leg.originID, leg.destinationID);
    if (busLine == null) throw Exception("bus line not found");

    final stopsIter = busLine.stops.skipWhile((s) => s.$2.id != leg.originID);
    final startIdx = stopsIter.firstOrNull?.$1;
    final endIdx = stopsIter.where((s) => s.$2.id == leg.destinationID).firstOrNull?.$1;
    if (startIdx == null || endIdx == null) throw Exception("valid bus line not found");

    final busPath = <(LatLng, (int, BusStop)?)>[];
    for (int i = startIdx; i <= endIdx; i++) {
      busPath.add((busLine.points[i], busLine.stops.where((s) => s.$1 == i).firstOrNull));
    }

    return NavOnBus(
      rt: maybeRt,
      departureStop: leg.originID,
      arrivalStop: leg.destinationID,
      trip: maybeTrip,
      busPath: busPath,
    );
  }

  @override
  String getTitle() {
    // TODO: implement getTitle
    return "($rt) Ride ${-1} more stops";
  }

  @override
  String getSubtitle() {
    // TODO: implement getSubtitle
    return "${-1} min";
  }

  @override
  // TODO: implement length
  double get length => super.length;

  @override
  // TODO: implement percent_complete
  double get percent_complete => super.percent_complete;

  @override
  List<NavigationStageStep> getSteps() {
    // TODO: implement getSteps
    return super.getSteps();
  }

  @override
  List<Marker> getMarkers() {
    // TODO: implement getMarkers
    return super.getMarkers();
  }

  @override
  List<Polyline> getPolylines() {
    // TODO: implement getPolylines
    return super.getPolylines();
  }

  @override
  Color getColor() {
    return RouteColorService.getRouteColor(rt);
  }

}

typedef Edge = ({ BusStop from, BusStop to, List<LatLng> points });
typedef AdjacencyEntry = ({ BusStop from, Set<({ BusStop stop, List<LatLng> points })> tos });
BusRouteLine? determineRouteOfBusLeg(
  Map<String, List<BusRouteLine>> routesCache, String rt, String originID, String destinationID
) {
  List<BusRouteLine> candidates = routesCache[rt] ?? [];

  // happy path
  final directLine = candidates
    .where((line) {
      final stpids = line.stops.map((s) => s.$2.id);
      return stpids.skipWhile((stpid) => stpid != originID).contains(destinationID);
    })
    .firstOrNull;
  if (directLine != null) return directLine;

  // big sad path: graph traverse the entire route...
  final Map<String, AdjacencyEntry> adjacency = {};  // for stpids
  // make the adjacency structure ...
  for (final line in candidates) {
    (int, BusStop)? prev;
    for (final (i, stop) in line.stops) {
      if (prev != null) {
        final (prevIdx, prevStop) = prev;
        // ignore: prefer_collection_literals (for better type inference)
        adjacency.putIfAbsent(prevStop.id, () => (from: prevStop, tos: Set()))
          .tos.add((stop: stop, points: line.points.sublist(prevIdx, i + 1)));
      }
      prev = (i, stop);
    }
  }
  // do breadth first search ...
  final Set<String> explored = {};
  final queue = ListQueue<(String, List<Edge>)>();
  queue.addLast((originID, []));

  while (queue.isNotEmpty) {
    final (stpid, edges) = queue.first;
    if (stpid == destinationID) break;
    queue.removeFirst();

    if (explored.contains(stpid)) continue;
    explored.add(stpid);

    final neighbors = adjacency[stpid];
    if (neighbors != null) {
      for (final entry in neighbors.tos) {
        queue.addLast((
          entry.stop.id,
          edges.followedBy([(from: neighbors.from, to: entry.stop, points: entry.points)]).toList()
         ));
      }
    }
  }

  if (queue.isEmpty || queue.first.$2.isEmpty) return null;
  final edges = queue.first.$2;

  List<LatLng> points = [LatLng(0.0, 0.0)];
  List<(int, BusStop)> stops = [(0, edges.first.from)];
  for (final e in edges) {
    points.removeLast();
    points.addAll(e.points);
    stops.add((points.length - 1, e.to));    
  }
  
  return BusRouteLine(
    points: points,
    stops: stops,
    routeId: candidates.first.routeId,
    color: candidates.fold(null, (acc, next) => acc ?? next.color),
    imageUrl: candidates.fold(null, (acc, next) => acc ?? next.imageUrl),
  );
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

// oops stage
// TODOs: 
class MissedBus extends NavigationStage { 
  // using the new title information method
  @override
  String getTitle() {
    // could be a more descriptive title who knows..
    return "Oops!";
  }

  // information for the popup 
  @override
  String getSubtitle() { 
    // Looks like these are for pop-ups, so maybe this can be part of a user prompt? 
    return "Looks like you might've missed your bus! Would you like to re-route?";
  }

  String route; // current route
  String nearest_stop; // nearest stop: ideally to get off
  String c_bus; // current bus i am/was on 
  String c_pos; // current position (maybe not str lat lng?)

  MissedBus({
    // Constructor for more stuff
    required this.route, 
    required this.nearest_stop,
    required this.c_bus,
    required this.c_pos,
  });

  // Core functionality + TODOs for Allen 
  // Main objectives for the "oops" stage:
  // - Acknowledge to user that they have missed expected bus
  // - Based on logic: immediately ask user to get off on next stop 
  // - Goal: Recalculate or call to recalcualte new route and redirect user to a nother stage ideally

  // Data Structure Implementation 
  // What we need: 
  // - hangon...

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

  final _eventController = StreamController<StageEvent>();

  Stream<StageEvent> get events => _eventController.stream;

  // To add stage events (i.e. if you miss the bus):
  // _controller.add(StageReroute(RerouteReason.wrongBus))
  // _controller.add(StageReroute(RerouteReason.walkPathChanged))
  // _controller.add(StageComplete()) // If your stage is complete!
  // Note to all frontend devs: Feel free to add additional RerouteReasons if you need them!

  void dispose() {
    _eventController.close();
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

  StreamSubscription<StageEvent>? _stageEventSub;

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

  NavigationOverlayHost? _overlay;

  void registerOverlay(NavigationOverlayHost overlay) {
    _overlay = overlay;
  }

  void unregisterOverlay(NavigationOverlayHost overlay) {
    if (_overlay == overlay) {
      _overlay = null;
    }
  }

  // Call to update if state changes require an update 
  void notifyOverlay() {
    _overlay?.onNavigationUpdated();
  }

  void _activateStageSub(NavigationStage stage) {
    // TODO: Call this whenever the stage is activated
    _stageEventSub?.cancel(); // Drop the old subscription
    _stageEventSub = stage.events.listen((event) {
      switch (event) {
        case StageComplete():
          // Move on to the next stage
        case StageReroute(:final reason):
          // Handle the reroute
      }
    });
  }

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
    _activateStageSub(stageList[currentStage]);
  }

  void previousStage() {
    currentStage = (currentStage - 1) % stageList.length;
    _activateStageSub(stageList[currentStage]);
  }

  // TODO: Add start()/stop() methods


  // - Allen: Get “Oops” code started. Find a way to talk to the NavigationOverlayWidget
  // - Find a way to get the two to talk to each other: I.e. whenever `NavigationOverlayWidget` is created, it calls a specific method inside NavigationManager that says "Hey, I'm here, please save me in a member variable", so when the "Oops" stage happens later you can call localReferenceToOverlayWidget.displayOopsDialog(...)
  //    The stage (e.g. "On bus") should call the "Oops" stage when it needs to
}

abstract class NavigationOverlayHost { 
  void displayOopsDialog(MissedBus state); // just for the Oops state for now...
  void onNavigationUpdated(); // call navigation overlay widget to refresh
}
// TODO: Call dispose() on stages as they are removed