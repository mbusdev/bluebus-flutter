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
import 'package:flutter/material.dart';
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

  // Broadcast so the NavigationManager can unsubscribe and resubscribe to the
  // same stage (e.g. when the user pages backwards) without the stream
  // complaining that it has already been listened to.
  final _eventController = StreamController<StageEvent>.broadcast();

  Stream<StageEvent> get events => _eventController.stream; // The NavigationManager does yourStage.events to listen in

  /// How a stage talks back to the NavigationManager. Call this from your
  /// stage (usually from receiveLocationUpdate) when something happens:
  ///    emit(StageComplete())                        // Your stage is done, move on to the next one
  ///    emit(StageReroute(RerouteReason.wrongBus))   // Something went wrong--this is what pops the "Oops" dialog
  ///    emit(StageReroute(RerouteReason.walkPathChanged))
  /// Note to all frontend devs: Feel free to add additional RerouteReasons if you need them!
  @protected
  void emit(StageEvent event) {
    if (_eventController.isClosed) return;
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }

  void initWithLeg(Leg leg) {
    // Do cool stuff to set up your Stage with an e.g. walking or bus leg
  }

  void receiveLocationUpdate(LatLng newLocation) {
    // Do whatever you need to with the current location.
    // You might want to do some processing (e.g. figure out if the user is close to the end of their walking path) and send a stage event, e.g.:
    //    emit(StageComplete()) // If the user has reached the end!
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

// // used to ensure that the stage is fully initialized
// class NavOnBusState {
//   Trip _trip;
//   String _departureStop;
//   String _arrivalStop;
//   final List<({ String? rt, List<LatLng> path })> busPathSegments;
//   // TODO: confirm that this can have no duplicates
//   final List<({ String? rt, LatLng location })> stopCoords;
  
//   // BusRouteLine _line;

//   NavOnBusState({
//     required Trip trip,
//     required String departureStop,
//     required String arrivalStop,
//     required this.busPathSegments, required this.stopCoords,
//   }) : _trip = trip,
//        _departureStop = departureStop,
//        _arrivalStop = arrivalStop;

//   String get departureStop => _departureStop;
//   String get arrivalStop => _arrivalStop;

//   String? get rt => stopCoords.firstOrNull?.rt;

//   List<StopTime> get stopTimes {
//     final List<StopTime> result = [];
//     for (final st in _trip.stopTimes.skipWhile(
//       (st) => st.stop != _departureStop,
//     )) {
//       result.add(st);
//       if (st.stop == _arrivalStop) {
//         break;
//       }
//     }
//     return result;
//   }
// }

// used to ensure that the stage is fully initialized
class NavOnBusState {
  String rt;
  // must contain only the taken stops and not the whole trip
  List<StopTime> stopTimes;
  List<StopCoord> stopCoords;
  List<BusPathSegment> pathSegments;
  BitmapDescriptor stopBitmap;

  NavOnBusState({
    required this.rt,
    required this.stopTimes,
    required this.stopCoords,
    required this.pathSegments,
    required this.stopBitmap,
  });
}

class NavOnBus extends NavigationStage {
  // late NavOnBusState state;
  // late BusLeg leg;
  // late String rt;
  // late List<StopCoord> stopCoords;
  // late List<BusPathSegment> pathSegments;
  // late BitmapDescriptor stopBitmap;
  late NavOnBusState _state;

  LatLng? _lastPosition;
  (int, double, double)? _snappedPos;

  NavOnBus();

  @override
  void initWithLeg(Leg leg) {
    if (leg is! BusLeg) {
      throw ArgumentError("leg is of the wrong type");
    }

    final stopTimes = <StopTime>[];
    for (final st in leg.trip.stopTimes.skipWhile(
      (st) =>
          st.stop != leg.originID ||
          math.min(st.arrivalTime, st.departureTime) < leg.startTime,
    )) {
      stopTimes.add(st);
      if (st.stop == leg.destinationID) {
        break;
      }
    }
    if (stopTimes.length < 2) throw FormatException("trip is too short");
    if (stopTimes.length != leg.stopCoords.length) {
      throw AssertionError(
        "stop times and coords should match, got ${stopTimes.length} and ${leg.stopCoords.length}\n${stopTimes.toString()}\n${leg.stopCoords.toString()}",
      );
    }

    _state = NavOnBusState(
      rt: leg.rt,
      stopTimes: stopTimes,
      stopCoords: leg.stopCoords,
      pathSegments: leg.busPathSegments,
      stopBitmap: BitmapDescriptor.defaultMarker,
    );

    // state = NavOnBusState(
    //   trip: leg.trip,
    //   departureStop: leg.originID,
    //   arrivalStop: leg.destinationID,
    //   busPathSegments: leg.busPathSegments,
    //   stopCoords: leg.stopCoords
    // );
  }

  @override
  void receiveLocationUpdate(LatLng newLocation) {
    _lastPosition = newLocation;
    final (i, j, dist) = _snapToPath(newLocation, _state.pathSegments);
    // exact value needs adjusting
    if (dist < 10.0) {
      _snappedPos = (i, j, dist);
    }
    // TODO: determine if stage is over
  }

  @override
  String getTitle() {
    // TODO: move route thing to a route icon widget
    final stopsRemaining = _state.stopCoords.length - getStepIndex() - 1;
    return "(${_state.rt} Ride $stopsRemaining more stops";
  }

  String getFixedTitle() {
    return "Board ${_state.rt}";
  }

  @override
  String getSubtitle() {
    return "Get off at ${getStopNameFromID(_state.stopTimes.last.stop)}";
  }

  @override
  // using seconds to match the walking stage right now, if you change this make
  // sure to adjust the use of length in percent_complete
  double get length {
    final sts = _state.stopTimes;
    return (sts.last.arrivalTime.toDouble() - sts.first.departureTime);
  }

  @override
  // uses the departure time of the last stop passed with respect to `trip` as
  // a baseline before adding progress past that stop
  double get percent_complete {
    final pos = _lastPosition;
    if (pos == null) return 0.0;

    final sts = _state.stopTimes;
    final stopCoords = _state.stopCoords;

    final stepIdx = getStepIndex();
    if (stepIdx == stopCoords.length - 1) {
      // at the end
      return 1.0;
    }
    final prevStopCoord = stopCoords[stepIdx];
    final nextStopCoord = stopCoords[stepIdx + 1];
    final snappedPos = _snappedPos;
    if (prevStopCoord.segmentIdx != nextStopCoord.segmentIdx || snappedPos == null) {
      // changing routes, path is unavailable, or location is unavailable
      // fallback to prev
      return (sts[stepIdx].arrivalTime.toDouble() - sts.first.departureTime) /
          length;
    }

    // final (prevStopIdx, _) = stops[stepIdx];
    // final (nextStopIdx, _) = stops[min(stepIdx + 1, stops.length - 1)];
    // final (pointsIdx, _) = pos.nearestPolylineIndexAndDistanceContinuous(
    //   points,
    // );
    final segment = _state.pathSegments[prevStopCoord.segmentIdx];
    final currStepTotalDist = segment.path
        .sublist(prevStopCoord.idxInSegment, nextStopCoord.idxInSegment + 1)
        .totalDistance();

    // compute distance past the stop
    var currStepMovedDist = segment.path
        .sublist(prevStopCoord.idxInSegment, snappedPos.$2.truncate() + 1)
        .totalDistance();
    final currSubsegmentDist = segment.path
        .sublist(
          snappedPos.$2.truncate(),
          min(snappedPos.$2.truncate() + 2, segment.path.length),
        )
        .totalDistance();
    currStepMovedDist += currSubsegmentDist * (snappedPos.$2 - snappedPos.$2.truncate());

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
    final pos = _snappedPos;
    if (pos == null) return 0;
    final (i, j, _) = pos;
    // return how many stops were passed
    return _state.stopCoords
            .takeWhile(
              (x) =>
                  x.segmentIdx < i ||
                  (x.segmentIdx == i && x.idxInSegment <= j),
            )
            .length -
        1;
  }

  @override
  List<NavigationStageStep> getSteps() {
    final color = RouteColorService.getRouteColor(_state.rt);
    final steps = _state.stopTimes
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
    return _state.stopCoords.indexed
        .map(
          (e) => 
            AdvancedMarker(
              markerId: MarkerId("navonbus_marker_${_state.rt}_${_state.stopTimes[e.$1].stop}"),
              flat: true,
              position: e.$2.location,
              zIndex: 2000,
              icon: _state.stopBitmap,
            ),
        )
        .toList();
  }

  @override
  List<Polyline> getPolylines() {
    // TODO: segment connection polylines
    var i = 0;
    return _state.pathSegments
        .map(
          (seg) => Polyline(
            polylineId: PolylineId("navonbus_polyline_${seg.hashCode}"),
            color: HSVColor.fromAHSV(1.0, (i++).toDouble() / 5.0 * 360.0, 1.0, 1.0).toColor(),//RouteColorService.getRouteColor(seg.rt ?? _state.rt).withRed((i++ / 255.0 * 40.0).toInt()),
            points: seg.path,
            zIndex: 1999,
          ),
        )
        .toList();
  }

  @override
  Color getColor() {
    return RouteColorService.getRouteColor(_state.rt);
  }

  static (int, double, double) _snapToPath(LatLng loc, List<BusPathSegment> segments) {
    final (i, (j, dist)) = segments.indexed
        .map(
          (e) =>
              (e.$1, loc.nearestPolylineIndexAndDistanceContinuous(e.$2.path)), // (idx, seg)
        )
        .reduce((e1, e2) => e1.$2.$2 < e2.$2.$2 ? e1 : e2); // (segIdx, (idxInSeg, dist))
    return (i, j, dist);
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
  WalkingLeg? leg;
  Color color = Colors.black;

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

  void setColor(Color newColor) {
    color = newColor; // Flutter won't let us call getColor(context, ...) because we can only get context from inside a widget. Thus, we have to thread it through all the way from map_screen.dart. Great.
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

    // TODO: update length and percent_complete here

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
  void initWithLeg(Leg leg_in) {
    if (leg_in is! WalkingLeg) throw ArgumentError('Leg was not a walking leg');
    final path = leg_in.pathCoords;
    leg = leg_in;

    if (path.isEmpty) {
      throw ArgumentError(
        'Walking leg from ${leg_in.origin} to ${leg_in.destination} has no path.',
      );
    }

    points = List<LatLng>.unmodifiable(path);
    _nextIndex = 0;

    length = leg_in.duration;
    percent_complete = 0.0;
  }

  @override
  List<Polyline> getPolylines() {
    return [
      Polyline(
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        polylineId: PolylineId('navigation_walking_${leg?.hashCode ?? "00"}'),
        points: points,
        color: color, // Walk line color
        width: 8, // line width
        patterns: [
          PatternItem.dot,
          // PatternItem.dash(30), // Longer dashes
          PatternItem.gap(15), // Longer gaps
        ],
      )
    ];

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

  void initFromJourney(Journey journey, Color walkingLineColor) {

    this.stageList.clear();

    for (Leg leg in journey.legs) {
      // TODO: Call initWithLeg(leg) constructor here if it's a Bus leg

      switch (leg) {
        case BusLeg():
          NavOnBus onBusStage = NavOnBus();
          onBusStage.initWithLeg(leg);
          this.stageList.add(onBusStage);
        case WalkingLeg():
          Walking walkingStage = Walking();
          walkingStage.setColor(walkingLineColor); // Because Flutter won't let us get a Context inside WalkingStage because it isn't a widget. Womp womp
          walkingStage.initWithLeg(leg);
          this.stageList.add(walkingStage);
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