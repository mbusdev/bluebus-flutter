import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:math' as math;

import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart' show BusStop;
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/utils/geometry.dart';
import 'package:bluebus/utils/time.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LineType { Dotted, Dashed}

class NavigationStageStep {
  String title;
  String? subtitle;
  String time;
  Color color;
  LineType lineType; // e.g. LineType.Dashed

  NavigationStageStep({
    required this.title,
    this.subtitle,
    required this.time,
    required this.color,
    required this.lineType
  });

  String getTitle() {
    return title;
  }

  String? getSubtitle() {
    return subtitle; // Return null if no subtitle
  }

  String getTime() {
    return time; // Get the time
  }

  Color? getColor() {
    return color; // Return null for neutral gray
  }

  LineType getLineType() {
    return lineType;
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

  bool hasRoundedCorners() {
    return false;
  }

  final _eventController = StreamController<StageEvent>();

  Stream<StageEvent> get events => _eventController.stream;

  void dispose() {
    _eventController.close();
  }

  void initWithLeg(Leg leg) {
    // Do cool stuff to set up your Stage with an e.g. walking or bus leg
  }

  void receiveLocationUpdate(LatLng newLocation) {
    // Do whatever you need to with the current location.
    // You might want to do some processing (e.g. figure out if the user is close to the end of their walking path) and send a stage event, e.g.:
    //    _controller.add(StageComplete()) // If the user has reached the end!
  }

}

enum RerouteReason {
  wrongBus,
  walkPathChanged
  // Feel free to add additional reasons as necessary
}


class BusPromptOption { 
  // DISCLAIMER: STRUCTURES SUBJECT TO CHANGE BECAUSE IM NOT SURE IF WE HAVE CUSTOM STRUCTURES 
  // going to remove this soon probably, since i can use the bus structure...
  final String code; // "CN" "BB"...
  final String label; // expanded name 
  final Color color; 
  final String? busNumber; // 3067 :)
  BusPromptOption({
    required this.code, 
    required this.label, 
    required this.color, 
    this.busNumber
  });
}

sealed class StageEvent {}
class StageComplete extends StageEvent {}
class StageReroute extends StageEvent {
  final RerouteReason reason; // e.g. wrong bus, missed stop
  StageReroute(this.reason);
}

// used to ensure that the stage is fully initialized
class NavOnBusState {
  Trip _trip;
  String _departureStop;
  String _arrivalStop;
  BusRouteLine _line;

  NavOnBusState({
    required Trip trip,
    required String departureStop,
    required String arrivalStop,
    required BusRouteLine line,
  }) : _trip = trip,
       _departureStop = departureStop,
       _arrivalStop = arrivalStop,
       _line = line;

  String get rt => _line.routeId;
  String get departureStop => _departureStop;
  String get arrivalStop => _arrivalStop;

  List<(int, BusStop)> get stops {
    final (depIdx, (depPointIdx, _)) = _line.stops.indexed.firstWhere(
      (x) => x.$2.$2.id == _departureStop
    );
    final (arrIdx, (arrPointIdx, _)) = _line.stops.indexed
      .skip(depIdx)
      .firstWhere((x) => x.$2.$2.id == _arrivalStop);
    return _line.stops
        .sublist(depIdx, arrIdx + 1)
        .map(
          (x) => switch (x) {
            (final pointIdx, final stop) => (pointIdx - depPointIdx, stop),
          },
        )
        .toList();
  }

  List<LatLng> get points {
    final (depIdx, (depPointIdx, _)) = _line.stops.indexed.firstWhere(
      (x) => x.$2.$2.id == _departureStop
    );
    final (arrIdx, (arrPointIdx, _)) = _line.stops.indexed
      .skip(depIdx)
      .firstWhere((x) => x.$2.$2.id == _arrivalStop);
    return _line.points.sublist(depPointIdx, arrPointIdx + 1);
  }

  List<StopTime> get stopTimes {
    final List<StopTime> result = [];
    for (final st in _trip.stopTimes.skipWhile(
      (st) => st.stop != _departureStop,
    )) {
      result.add(st);
      if (st.stop == _arrivalStop) {
        break;
      }
    }
    return result;
  }
}

class NavOnBus extends NavigationStage {
  late NavOnBusState state;
  late BitmapDescriptor stopBitmap;
  LatLng? lastPosition;

  NavOnBus();

  @override
  void initWithLeg(Leg leg) {
    if (leg.mode != LegMode.bus) {
      throw ArgumentError("leg is of the wrong type");
    }
    final rt = leg.rt;
    final trip = leg.trip;
    if (rt == null ||
        trip == null ||
        // leg.stopTimes == null ||
        leg.originID == '' ||
        leg.destinationID == '') {
      throw FormatException("leg was malformed");
    }
    if (trip.stopTimes.length < 2) throw FormatException("trip is too short");
    // TODO: use info from backend instead of this placeholder, check that line
    // has the same number of stops
    final points = <LatLng>[];
    final stops = <(int, BusStop)>[];

    for (final st in trip.stopTimes.skipWhile(
      (st) => st.stop != leg.originID,
    )) {
      final loc = getLatLongFromStopID(st.stop);
      if (loc == null) continue;
      points.add(loc);
      stops.add((
        stops.length,
        BusStop(
          id: st.stop,
          name: getStopNameFromID(st.stop),
          location: loc,
          routeId: rt,
          rotation: 0.0,
          isRide: isRide(rt),
        ),
      ));
    }
    final line = BusRouteLine(
      routeId: rt,
      points: points,
      stops: stops,
      color: RouteColorService.getRouteColor(rt),
      imageUrl: null,
    );
    state = NavOnBusState(
      trip: trip,
      departureStop: leg.originID,
      arrivalStop: leg.destinationID,
      line: line,
    );
    // const svgString = '<svg width="19" height="19" viewBox="0 0 19 19" fill="none" xmlns="http://www.w3.org/2000/svg">'
    //   + '<circle cx="9.5" cy="9.5" r="8" fill="white" stroke="black" stroke-width="3"/>'
    //   + '</svg>';

    // // final svg = SvgPicture.string(svgString, width: 19, height: 19,);
    // final pictureInfo = vg.loadPicture(const SvgStringLoader(svgString), null);
    // pictureInfo.
    // svg.clipBehavior
    // stopBitmap = BitmapDescriptor.bytes();
    stopBitmap = BitmapDescriptor.defaultMarker;
  }

  @override
  void receiveLocationUpdate(LatLng newLocation) {
    lastPosition = newLocation;
    // TODO: determine if stage is over
  }

  @override
  String getTitle() {
    // TODO: move route thing to a route icon widget
    final stopsRemaining = state.stops.length - getStepIndex() - 1;
    return "(${state.rt}) Ride $stopsRemaining more stops";
  }

  String getFixedTitle() {
    return "Board ${state.rt}";
  }

  @override
  String getSubtitle() {
    return "Get off at ${getStopNameFromID(state.arrivalStop)}";
  }

  @override
  // using seconds to match the walking stage right now, if you change this make
  // sure to adjust the use of length in percent_complete
  double get length {
    final sts = state.stopTimes;
    return (sts.last.arrivalTime.toDouble() - sts.first.departureTime);
  }

  @override
  // uses the departure time of the last stop passed with respect to `trip` as
  // a baseline before adding progress past that stop
  double get percent_complete {
    final pos = lastPosition;
    if (pos == null) return 0;

    final sts = state.stopTimes;
    final stops = state.stops;
    final points = state.points;

    final stepIdx = getStepIndex();
    final (prevStopIdx, _) = stops[stepIdx];
    final (nextStopIdx, _) = stops[min(stepIdx + 1, stops.length - 1)];
    final (pointsIdx, _) = pos.nearestPolylineIndexAndDistanceContinuous(
      points,
    );
    final currStepTotalDist = points
        .sublist(prevStopIdx, nextStopIdx + 1)
        .totalDistance();

    // compute distance past the stop
    var currStepMovedDist = points
        .sublist(prevStopIdx, pointsIdx.truncate() + 1)
        .totalDistance();
    final currSegmentDist = points
        .sublist(
          pointsIdx.truncate(),
          min(pointsIdx.truncate() + 2, points.length),
        )
        .totalDistance();
    currStepMovedDist += currSegmentDist * (pointsIdx - pointsIdx.truncate());

    var progress =
        sts[stepIdx].arrivalTime.toDouble() - sts.first.departureTime;
    if (currStepTotalDist != 0.0) {
      // add progress past the stop
      progress +=
          (currStepMovedDist / currStepTotalDist) *
          (sts[min(stepIdx + 1, sts.length - 1)].arrivalTime -
              sts[stepIdx].arrivalTime);
    }
    return progress / length;
  }

  /// the index of the last step reached/passed
  int getStepIndex() {
    final pos = lastPosition;
    if (pos == null) return 0;
    // project lastPosition onto polyline
    final (idx, _) = pos.nearestPolylineIndexAndDistanceContinuous(state.points);
    // return how many stops were passed
    return state.stops.takeWhile((x) => x.$1 <= idx).length - 1;
  }

  @override
  List<NavigationStageStep> getSteps() {
    final color = RouteColorService.getRouteColor(state.rt);
    final steps = state.stopTimes
        .map(
          (st) => NavigationStageStep(
            title: getStopNameFromID(st.stop),
            time: convertSecondsToFormattedTime(st.departureTime),
            color: color,
            lineType: LineType.Dotted,
          ),
        )
        .toList();
    steps[0].title = getFixedTitle();
    steps[steps.length - 1].title =
        "Get off at ${steps[steps.length - 1].title}";
    return steps;
  }

  @override
  List<Marker> getMarkers() {
    return state.stops
        .map(
          (x) => switch (x) {
            (int _, BusStop stop) => AdvancedMarker(
              markerId: MarkerId("navonbus_marker_${state.rt}_${stop.id}"),
              flat: true,
              position: stop.location,
              zIndex: 2000,
              icon: stopBitmap,
            ),
          },
        )
        .toList();
  }

  @override
  List<Polyline> getPolylines() {
    return [
      Polyline(
        polylineId: PolylineId("navonbus_polyline_${state.rt}"),
        color: RouteColorService.getRouteColor(state.rt),
        points: state.points,
        zIndex: 1999,
      ),
    ];
  }

  @override
  Color getColor() {
    return RouteColorService.getRouteColor(state.rt);
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
// TODOs: MOVING TO NAVIGATION MANAGER
// class MissedBus extends NavigationStage { 
//   // using the new title information method
//   @override
//   String getTitle() {
//     // could be a more descriptive title who knows..
//     return "Oops!";
//   }

//   // information for the popup 
//   @override
//   String getSubtitle() { 
//     // Looks like these are for pop-ups, so maybe this can be part of a user prompt? 
//     return "Looks like you might've missed your bus! Would you like to re-route?";
//   }

//   String route; // current route
//   String nearest_stop; // nearest stop: ideally to get off
//   String c_bus; // current bus i am/was on 
//   String c_pos; // current position (maybe not str lat lng?)

//   MissedBus({
//     // Constructor for more stuff
//     required this.route, 
//     required this.nearest_stop,
//     required this.c_bus,
//     required this.c_pos,
//   });
// }


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
  @override
  bool receiveLocationUpdate(LatLng newLocation) {
    currWalkingPos = newLocation;
    
    // check if it has not reached new waypoint
    if (_nextIndex >= points.length ||
        _distMeters(newLocation, points[_nextIndex]) > _reachThresholdMeters) {
      return false;
    }

    // if it has reached new waypoint, update index, length left, and percent complete
    _nextIndex++;

    // TODO:
    // update length and percent_complete here

    return true;
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

  // Calculates the distance left in the walking stage
  // in feet based on the current user position
  double getDistanceLeftFeet() {
    double distLeft = 0;
    if (currWalkingPos != null) { // if GPS is broken/off, use distance from _nextIndex to the destination
      distLeft = _distMeters(currWalkingPos!, points[_nextIndex]);
    }
    // calculate remaining walking distance
    for (int i = _nextIndex; i < points.length - 1; ++i) {
      distLeft += _distMeters(points[i], points[i + 1]);
    }
    return (distLeft * 3.28084);
  }

  // Get summary text that shows up in steps view
  // such as "Walk 67 ft"
  // @override
  String getFixedTitle() {
    return "Walk ${getDistanceLeftFeet().round()} ft";
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

  // Initializes the Walking stage given a Leg.
  @override
  void initWithLeg(Leg leg) {
    final path = leg.pathCoords;

    if (path == null || path.isEmpty) {
      throw ArgumentError(
        'Walking leg from ${leg.origin} to ${leg.destination} has no path.',
      );
    }

    points = List<LatLng>.unmodifiable(path);
    _nextIndex = 0;

    length = leg.duration;
    percent_complete = 0.0;
  }
}


class DemoStage extends NavigationStage {

  String getTitle() {
    return "This is a demo! #$favoriteNumber";
  }

  String getSubtitle() {
    return "Look, here's a subtitle too #$favoriteNumber";
  }

  double length = 15.0; // In minutes
  double percent_complete = 0.110;

  LatLng startPoint;
  LatLng endPoint;

  double favoriteNumber;
  Color color = Colors.black;
  LineType lineType;

  DemoStage({
    required this.favoriteNumber,
    required this.length,
    required this.percent_complete,
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.lineType
  });

  @override
  Color getColor() { // Return a random color
    // return Color(this.favoriteNumber.hashCode | 0xFF000000); // Return a color derived from this.favoriteNumber
    return color;
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

  List<NavigationStageStep> getSteps() {
    return [
      NavigationStageStep(
        title: "Step 1",
        subtitle: "Step 1 subtitle",
        time: '1:23 AM',
        color: getColor(), // Use the stage's color in our demo
        // lineType: LineType.Dashed,
        lineType: this.lineType
      ),
      NavigationStageStep(
        title: favoriteNumber == 3 ? "Step 2 I'm making this title really long to test text wrapping. It's getting even longer now--practically absurd for the name of a bus stop but great for UI testing. " : "Step 2",
        subtitle: "Step 2 subtitle",
        time: '4:56 AM',
        color: getColor(), // Use the stage's color in our demo
        // lineType: LineType.Dashed,
        lineType: this.lineType
      ),
      NavigationStageStep(
        title: "Step 3",
        subtitle: "Step 3 subtitle",
        time: '7:89 AM',
        color: getColor(), // Use the stage's color in our demo
        // lineType: LineType.Dashed,
        lineType: this.lineType
      )
    ]; // Get navigation stage steps
  }

  bool hasRoundedCorners() {
    return favoriteNumber == 2;
  }

  final _eventController = StreamController<StageEvent>();

  Stream<StageEvent> get events => _eventController.stream; // This is so the NavigationController can do yourStage.events and access your event controller

  // To add stage events (i.e. if you miss the bus):
  // _eventController.add(StageReroute(RerouteReason.wrongBus))
  // _eventController.add(StageReroute(RerouteReason.walkPathChanged))
  // _eventController.add(StageComplete()) // If your stage is complete!
  // Note to all frontend devs: Feel free to add additional RerouteReasons if you need them!

  void dispose() {
    _eventController.close();
  }

  // New!
  void initWithLeg(Leg leg) {
    // Do cool stuff to set up your Stage with an e.g. walking or bus leg
  }

  void receiveLocationUpdate(LatLng newLocation) {
    // Do whatever you need to with the current location.
    // You might want to do some processing (e.g. figure out if the user is close to the end of their walking path) and send a stage event, e.g.:
    //    _eventController.add(StageComplete()) // If the user has reached the end!
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
          endPoint: LatLng(42.281291, -83.743918),
          color: darkColors[ColorType.navigationStepsGray]!, // TODO: Make this dynamic. This will be messy since we need to do something about context in getColor(context, color Type)
          lineType: LineType.Dashed
        ),
        DemoStage(
          favoriteNumber: 2,
          length: 33,
          percent_complete: 0.23,
          startPoint: LatLng(42.281291, -83.743918),
          endPoint: LatLng(42.287031, -83.743532),
          color: Colors.purple,
          lineType: LineType.Dotted
        ),
        DemoStage(
          favoriteNumber: 3,
          length: 4,
          percent_complete: 0.0,
          startPoint: LatLng(42.287031, -83.743532),
          endPoint: LatLng(42.289689, -83.738435),
          color: darkColors[ColorType.navigationStepsGray]!,
          lineType: LineType.Dashed
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

  // Overlay can display the "which bus are you on?" prompt
  // We can call this
  void showOopsDialog() {
    _overlay?.displayOopsDialog();
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

  void initFromJourney(Journey journey) {

    this.stageList.clear();

    for (Leg leg in journey.legs) {
      // TODO: Call initWithLeg(leg) constructor here if it's a Bus leg

      if (leg.mode == LegMode.walk) {
        Walking walkingStage = Walking();
        walkingStage.initWithLeg(leg);
        this.stageList.add(walkingStage);
      } else if (leg.mode == LegMode.bus) {
        NavOnBus onBusStage = NavOnBus();
        onBusStage.initWithLeg(leg);
        this.stageList.add(onBusStage);
      }
    }

    // this.stageList.add(
    //   DemoStage(
    //   favoriteNumber: 7,
    //   length: 20.0,
    //   percent_complete: 0.72,
    //   startPoint: LatLng(42.297493, -83.710782),
    //   endPoint: LatLng(42.398493, -83.811782),
    //   color: Colors.orange,
    //   lineType: LineType.Dashed
    //  )
    // );

    _overlay?.onNavigationUpdated();
    rebuildMarkersAndPolylines();

  }

  // TODO: Add start()/stop() methods


  // - Allen: Get “Oops” code started. Find a way to talk to the NavigationOverlayWidget
  // - Find a way to get the two to talk to each other: I.e. whenever `NavigationOverlayWidget` is created, it calls a specific method inside NavigationManager that says "Hey, I'm here, please save me in a member variable", so when the "Oops" stage happens later you can call localReferenceToOverlayWidget.displayOopsDialog(...)
  //    The stage (e.g. "On bus") should call the "Oops" stage when it needs to
}

abstract class NavigationOverlayHost {
  void displayOopsDialog(); // just for the Oops state for now...
  void onNavigationUpdated(); // call navigation overlay widget to refresh
}
// TODO: Call dispose() on stages as they are removed