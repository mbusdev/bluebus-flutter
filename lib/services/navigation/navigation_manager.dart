import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'package:bluebus/services/map_image_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart' show BusStop, BusWithPrediction;
import 'package:bluebus/services/bus_info_service.dart' show fetchStopData;
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/journey_repository.dart';
import 'package:bluebus/services/map_layers/navigation_layer.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/utils/geometry.dart';
import 'package:bluebus/utils/time.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bluebus/services/map_image_service.dart';

enum LineType { Dotted, Dashed }

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
    required this.lineType,
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

// stage transitions are based on user leaving or entering a radius around POI
// "Trustworthiness" of a fix, does not trigger if above tolerance
// (updated) with testing data for 20m
const double usableFixAccuracyMeters = 20.0;

// within a radius zone (ie. a stop or end of walk etc...)
const double enterRadiusMeters = 35.0;

// counts leaving a stop at this many meters, increased tolerance to account for wiggle room
const double leaveRadiusMeters = 90.0;

bool isUsableFix(Position p) => p.accuracy <= usableFixAccuracyMeters;

double distanceMeters(Position p, LatLng point) =>
    LatLng(p.latitude, p.longitude).haversineDistanceMetersTo(point);

/// Minutes until the next [routeId] bus reaches the stop, from that stop's
/// live predictions, or null if none are for this route. Prefers the vehicle
/// the planner picked ([vehicleId]) when the feed has it, otherwise the
/// soonest bus on the route. "DUE" counts as 0; anything else that isn't a
/// number (eg. "DLY") is skipped.
int? soonestPredictionMinutes(
  List<BusWithPrediction> predictions, {
  required String routeId,
  String vehicleId = '',
}) {
  int? soonest;
  int? planned;
  for (final BusWithPrediction p in predictions) {
    if (p.id != routeId) continue;
    final int? minutes = p.prediction == "DUE"
        ? 0
        : int.tryParse(p.prediction.trim());
    if (minutes == null) continue;
    if (soonest == null || minutes < soonest) soonest = minutes;
    if (vehicleId.isNotEmpty && p.vehicleId == vehicleId) {
      if (planned == null || minutes < planned) planned = minutes;
    }
  }
  return planned ?? soonest;
}

sealed class NavigationStage {
  // String title = "..."; //Don't use this anymore--implement getTitle() instead
  String getTitle() {
    return "Swim forward"; // Title displayed on the big bar at the top
  }

  String getSubtitle() {
    return "Swim for 200 meters"; // Subtitle displayed on the big bar at the top
  }

  // Summary text shown in the steps list. Unlike getTitle(), this describes the
  // whole stage rather than the next thing to do, so override it if the two differ.
  String getFixedTitle() {
    return getTitle();
  }

  double length =
      0.0; // Estimated length of your segment, in minutes (i.e. is it a 20-minute walk or 12-minute bus ride?)
  double percent_complete =
      0.0; // Estimated completion percentage of your segment (i.e. if you're 32% of the way through your walk)

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

  void receiveLocationUpdate(Position p) {
    // Do whatever you need to with the current location.
    // You might want to do some processing (e.g. figure out if the user is close to the end of their walking path) and send a stage event, e.g.:
    //    emit(StageComplete()) // If the user has reached the end!
  }

  // Broadcast so the NavigationManager can unsubscribe and resubscribe to the
  // same stage (e.g. when the user pages backwards) without the stream
  // complaining that it has already been listened to.
  final _eventController = StreamController<StageEvent>.broadcast();

  Stream<StageEvent> get events => _eventController
      .stream; // The NavigationManager does yourStage.events to listen in

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
}

enum RerouteReason {
  wrongBus,
  walkPathChanged,
  missedBus, // User clicks "I missed bus"
  // Feel free to add additional reasons as necessary
}

// Info for missed bus prompt, exclusively dependent on user loc
class MissedBusInfo {
  final String routeId;
  final String stopId; // The stop the user was meant to board at
  final String stopName;
  final DateTime leftStopAt; // used for timing

  MissedBusInfo({
    required this.routeId,
    required this.stopId,
    required this.stopName,
    required this.leftStopAt,
  });
}

/// What the "your bus is arriving" card shows: the next bus the user still has
/// to catch, and when it gets to their stop.
class UpcomingBusInfo {
  final String routeId;
  final String stopId;
  final String stopName;

  /// When the bus reaches the stop, or null if neither the live feed nor the
  /// timetable knows.
  final DateTime? arrivesAt;

  /// Whether [arrivesAt] is a live prediction rather than the timetable.
  final bool live;

  UpcomingBusInfo({
    required this.routeId,
    required this.stopId,
    required this.stopName,
    required this.arrivesAt,
    required this.live,
  });
}

/// Gets the live predictions for a stop. The real one is fetchStopData; tests
/// pass their own so they never touch the network.
typedef StopPredictionFetcher =
    Future<List<BusWithPrediction>> Function(String stopId);

sealed class StageEvent {}

class StageComplete extends StageEvent {}

class StageReroute extends StageEvent {
  final RerouteReason reason; // e.g. wrong bus, missed stop
  StageReroute(this.reason);
}

// Raised when user has based on location departed from bus stop
class StageLeftStop extends StageEvent {
  final MissedBusInfo info;
  StageLeftStop(this.info);
} // summons prompt

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
      (x) => x.$2.$2.id == _departureStop,
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
      (x) => x.$2.$2.id == _departureStop,
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
  late BitmapDescriptor stopBitmap = BitmapDescriptor.defaultMarker;
  LatLng? lastPosition;

  late Leg _leg;

  // Whether the user has been at the boarding stop, ie. waiting for the bus
  bool reachedBoardingStop = false;

  // Set once this stage has raised prompt so it only ever prompts once
  bool leftStopPrompted = false;

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
    // stopBitmap = MapImageService.get

    _leg = leg;

    // Both getters throw if the boarding or arrival stop had no coordinates
    // (those are skipped above). Better to find out now, so the manager can
    // reject the journey, than halfway through drawing the overlay.
    final legPoints = state.points;
    state.stops;
    _boardingStop = legPoints.first;
    _arrivalStop = legPoints.last;
    _pathMeters = legPoints.totalDistance();
  }

  /// Length of the ride along its stops, worked out once in initWithLeg.
  double _pathMeters = 0;

  /// A rough average bus speed, stops included (~15 mph), for when the
  /// timetable doesn't say how long a ride takes.
  static const double _assumedBusMetersPerSecond = 7.0;

  /// Seconds between leaving the boarding stop and reaching the arrival stop,
  /// per the timetable. Can be 0: timetable times are whole minutes, and the
  /// planner has given short rides every stop at the same minute.
  double get _scheduledSeconds {
    final sts = state.stopTimes;
    return (sts.last.arrivalTime - sts.first.departureTime).toDouble();
  }

  // Looked up once here rather than on every GPS fix
  late LatLng _boardingStop;
  late LatLng _arrivalStop;

  /// Whether the user has left on (or walked away from) this bus: they left
  /// the boarding stop, which is also what raises the missed bus prompt.
  /// Until then the "your bus is arriving" card is about this bus.
  bool get departed => leftStopPrompted;

  String get routeId => state.rt;
  String get boardingStopId => _leg.originID;

  /// The vehicle the planner expects, or '' if it didn't say.
  String get plannedVehicleId => _leg.trip?.vid ?? '';

  /// When the timetable has this bus leaving the boarding stop.
  DateTime? get scheduledDeparture {
    final List<StopTime> times = state.stopTimes;
    if (times.isEmpty) return null;
    return serviceSecondsToDateTime(times.first.departureTime);
  }

  // entering boarding stop circle = waiting for bus
  // leaving boarding stop circle = departed, prompt missed bus
  // entering the arrival stop circle = arrived
  @override
  void receiveLocationUpdate(Position p) {
    lastPosition = LatLng(p.latitude, p.longitude);

    // Reject if fix tolerance is poor
    if (!isUsableFix(p)) return;

    final double fromBoardingStop = distanceMeters(p, _boardingStop);
    if (fromBoardingStop <= enterRadiusMeters) {
      reachedBoardingStop = true;
    } else if (reachedBoardingStop &&
        !leftStopPrompted &&
        fromBoardingStop >= leaveRadiusMeters) {
      _raiseLeftStop(DateTime.now());
    }

    // Emitted on every fix to ensure ability to complete, must also be in stage
    if (distanceMeters(p, _arrivalStop) <= enterRadiusMeters) {
      emit(StageComplete());
    }
  }

  // TESTING ONLY!!! (Will force missed bus prompt unconditionally)
  void debugForceLeftStop() {
    if (leftStopPrompted) return;
    _raiseLeftStop(DateTime.now());
  }

  void _raiseLeftStop(DateTime now) {
    leftStopPrompted = true;
    emit(
      StageLeftStop(
        MissedBusInfo(
          routeId: state.rt,
          stopId: _leg.originID,
          stopName: getStopNameFromID(_leg.originID),
          leftStopAt: now,
        ),
      ),
    );
  }

  @override
  String getTitle() {
    // TODO: move route thing to a route icon widget
    final stopsRemaining = state.stops.length - getStepIndex() - 1;
    return "(${state.rt}) Ride $stopsRemaining more stops";
  }

  @override
  String getFixedTitle() {
    return "Board ${RouteColorService.getRouteName(state.rt)}";
  }

  @override
  String getSubtitle() {
    return "Get off at ${getStopNameFromID(state.arrivalStop)}";
  }

  @override
  // using seconds to match the walking stage right now, if you change this make
  // sure to adjust the use of length in percent_complete
  //
  // Never less than the ride's distance at an average bus speed, so a ride the
  // timetable gives 0 minutes still shows up in the progress bar and moves the
  // dot (instead of a 0-wide segment and a 0/0 progress).
  double get length {
    return max(_scheduledSeconds, _pathMeters / _assumedBusMetersPerSecond);
  }

  @override
  // uses the departure time of the last stop passed with respect to `trip` as
  // a baseline before adding progress past that stop
  double get percent_complete {
    final pos = lastPosition;
    if (pos == null) return 0;

    // No time span to measure against, so go by distance along the ride
    final double scheduled = _scheduledSeconds;
    if (scheduled <= 0) return _distanceFraction(pos);

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
    return (progress / scheduled).clamp(0.0, 1.0);
  }

  /// How far along the ride's path [pos] is, 0 to 1.
  double _distanceFraction(LatLng pos) {
    final points = state.points;
    if (_pathMeters <= 0) return 0;
    final (double along, _) = pos.nearestPolylineIndexAndDistanceContinuous(
      points,
    );
    final int whole = along.floor();
    double covered = points.sublist(0, whole + 1).totalDistance();
    if (whole < points.length - 1) {
      covered +=
          points[whole].haversineDistanceMetersTo(points[whole + 1]) *
          (along - whole);
    }
    return (covered / _pathMeters).clamp(0.0, 1.0);
  }

  /// the index of the last step reached/passed
  int getStepIndex() {
    final pos = lastPosition;
    if (pos == null) return 0;
    // project lastPosition onto polyline
    final (idx, _) = pos.nearestPolylineIndexAndDistanceContinuous(
      state.points,
    );
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
  bool hasRoundedCorners() {
    return true;
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
              icon: stop.id == state.departureStop
                  ? MapImageService.getOnBusStop() ?? stopBitmap
                  : stop.id == state.arrivalStop
                      ? MapImageService.getOffBusStop() ?? stopBitmap
                      : MapImageService.navigationIntermediateStopIcon,
              // icon: ,
              anchor: const Offset(0.5, 0.5)
              // icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
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
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    ];
  }

  @override
  Color getColor() {
    return RouteColorService.getRouteColor(state.rt);
  }
}

typedef Edge = ({BusStop from, BusStop to, List<LatLng> points});
typedef AdjacencyEntry = ({
  BusStop from,
  Set<({BusStop stop, List<LatLng> points})> tos,
});
BusRouteLine? determineRouteOfBusLeg(
  Map<String, List<BusRouteLine>> routesCache,
  String rt,
  String originID,
  String destinationID,
) {
  List<BusRouteLine> candidates = routesCache[rt] ?? [];

  // happy path
  final directLine = candidates.where((line) {
    final stpids = line.stops.map((s) => s.$2.id);
    return stpids
        .skipWhile((stpid) => stpid != originID)
        .contains(destinationID);
  }).firstOrNull;
  if (directLine != null) return directLine;

  // big sad path: graph traverse the entire route...
  final Map<String, AdjacencyEntry> adjacency = {}; // for stpids
  // make the adjacency structure ...
  for (final line in candidates) {
    (int, BusStop)? prev;
    for (final (i, stop) in line.stops) {
      if (prev != null) {
        final (prevIdx, prevStop) = prev;
        // ignore: prefer_collection_literals (for better type inference)
        adjacency
            .putIfAbsent(prevStop.id, () => (from: prevStop, tos: Set()))
            .tos
            .add((stop: stop, points: line.points.sublist(prevIdx, i + 1)));
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
          edges.followedBy([
            (from: neighbors.from, to: entry.stop, points: entry.points),
          ]).toList(),
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

class ChooseBus extends NavigationStage {
  String title = "Choose a Bus";
  //Not sure if we actually need this. Depends on if we want to filter out some buses from certain stops.
  List<Bus> potentialBuses = [];
  List<BusStop> potentialStops = [];
  // If you have a list of buses to board and stops,
  // this can help you display a bus and the stop you will board
  // This could be simplified more, probably by picking up data from another function
}

// Deprecated Oops Stage was here: see in manager below

//I believe this is just NavWalking but I'm doing it here to be sure.
class Walking extends NavigationStage {
  List<LatLng> points = [
    //dummy pts taken from google maps by the cctc (replace later)
    const LatLng(42.27792397921826, -83.73596985653457),
    const LatLng(42.27756042901099, -83.7359661838265),
    const LatLng(42.27754197988967, -83.73706331473826),
    const LatLng(42.2775215703816, -83.73809993417933),
    const LatLng(42.278481544159916, -83.73811396072821),
  ];
  Leg? leg;
  Color color = Colors.black;

  LatLng? currWalkingPos = const LatLng(
    42.27831772684626,
    -83.73599054149456,
  ); //near cctc (replace w user's location)

  int _nextIndex = 0;
  static const double _reachThresholdMeters = 15.0;

  // True once the user has reached the end of the walk
  bool _completed = false;

  // Length of the whole walk along its path, worked out once in initWithLeg
  double _totalMeters = 0;

  // Similar to bus stage progress, updates progress bar dot :)
  @override
  double get percent_complete {
    if (_completed) return 1.0;
    final LatLng? pos = currWalkingPos;
    if (pos == null || _totalMeters <= 0) return 0.0;

    final (double along, _) = pos.nearestPolylineIndexAndDistanceContinuous(
      points,
    );
    final int whole = along.floor();
    double covered = points.sublist(0, whole + 1).totalDistance();
    if (whole < points.length - 1) {
      covered +=
          points[whole].haversineDistanceMetersTo(points[whole + 1]) *
          (along - whole);
    }
    return (covered / _totalMeters).clamp(0.0, 1.0);
  }

  double _distMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final s =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * R * math.asin(math.sqrt(s));
  }

  double _bearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void setColor(Color newColor) {
    color =
        newColor; // Flutter won't let us call getColor(context, ...) because we can only get context from inside a widget. Thus, we have to thread it through all the way from map_screen.dart. Great.
  }

  //call this whenever a new gps fix arrives, returns true if a waypoint was just cleared (so the ui can refresh)
  @override
  bool receiveLocationUpdate(Position p) {
    LatLng newLocation = LatLng(p.latitude, p.longitude);
    currWalkingPos = LatLng(p.latitude, p.longitude);

    // The walk is over once the user is at its end, also similar to bus stage
    if (isUsableFix(p) && distanceMeters(p, points.last) <= enterRadiusMeters) {
      _completed = true;
      emit(StageComplete());
    }

    // check if it has not reached new waypoint
    if (_nextIndex >= points.length ||
        _distMeters(newLocation, points[_nextIndex]) > _reachThresholdMeters) {
      return false;
    }

    // if it has reached new waypoint, update index (percent_complete works
    // itself out from the user's position)
    _nextIndex++;

    return true;
  }

  // (TODO) We may want to make this not be extra precise ft wise
  // Consider rounding to nearest 50 feet? 
  @override
  String getTitle() {
    if (_completed || _nextIndex >= points.length) {
      return "You've arrived!";
    }
    final pos = currWalkingPos;
    if (pos == null) {
      return "Acquiring GPS…";
    }
    final (String? turn, double meters) = _nextTurn(pos);
    final feet = (meters * 3.28084).round();
    return turn == null ? "Continue for $feet ft" : "$turn in $feet ft";
  }

  // what is a turn what is not a turn, 30 degrees or less is a curve lol
  static const double _turnThresholdDegrees = 30.0;

  // Paths often round a corner over a few close points, so the turn at a
  // point is judged from this far before it to this far after it.
  static const double _turnWindowMeters = 10.0;

  /// The next turn ahead of the user and how far along the path it is, or a
  /// null turn (and the distance left to walk) if there isn't one.
  ///
  /// Turns are read from the path's own shape, ie. the direction it arrives
  /// at a point versus the direction it leaves. Measuring from where the user
  /// is relative to the path mostly picked up GPS noise, giving left for right
  /// and U-turns on a straight walk.
  (String?, double) _nextTurn(LatLng pos) {
    final (double along, _) = pos.nearestPolylineIndexAndDistanceContinuous(
      points,
    );
    final int ahead = min(along.floor() + 1, points.length - 1);
    double meters = _distMeters(pos, points[ahead]);
    for (int i = ahead; i < points.length - 1; i++) {
      // Builds in a bit of wiggle room for ending the walk
      if (_distMeters(points[i], points.last) > enterRadiusMeters) {
        final String? turn = _turnAt(i);
        if (turn != null) return (turn, meters);
      }
      meters += _distMeters(points[i], points[i + 1]);
    }
    return (null, meters);
  }

  /// What the path does at point i: "Turn right", "Turn left", "U-turn",
  /// or null for (roughly) straight on.
  String? _turnAt(int i) {
    int before = i - 1;
    double back = _distMeters(points[before], points[i]);
    while (before > 0 && back < _turnWindowMeters) {
      before--;
      back += _distMeters(points[before], points[before + 1]);
    }
    int after = i + 1;
    double forward = _distMeters(points[i], points[after]);
    while (after < points.length - 1 && forward < _turnWindowMeters) {
      forward += _distMeters(points[after], points[after + 1]);
      after++;
    }
    // Repeated points, so there's no direction to speak of
    if (back < 1 || forward < 1) return null;

    // Clockwise change in heading, so 0-180 is to the right
    final double change = (_bearing(points[i], points[after]) 
                            - _bearing(points[before], points[i]) 
                            + 360) 
                          % 360;
    // sorry Isaac this part is slightly unreadable
    if (change < _turnThresholdDegrees ||
        change > 360 - _turnThresholdDegrees) {
      return null;
    }
    if (change <= 150) return "Turn right";
    if (change >= 210) return "Turn left";
    return "U-turn";
  }

  // Calculates the distance left in the walking stage
  // in feet based on the current user position
  double getDistanceLeftFeet() {
    double distLeft = 0;
    if (currWalkingPos != null) {
      // if GPS is broken/off, use distance from _nextIndex to the destination
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
  @override
  String getFixedTitle() {
    return "Walk ${(length / 60).ceil()} min";
  }

  @override
  String getSubtitle() {
    if (_completed || _nextIndex >= points.length) {
      return "Walk complete";
    }
    return "Waypoint ${_nextIndex + 1} of ${points.length}";
  }

  // Initializes the Walking stage given a Leg.
  @override
  void initWithLeg(Leg leg_in) {
    final path = leg_in.pathCoords;
    leg = leg_in;

    if (path == null || path.isEmpty) {
      throw ArgumentError(
        'Walking leg from ${leg_in.origin} to ${leg_in.destination} has no path.',
      );
    }

    points = List<LatLng>.unmodifiable(path);
    _nextIndex = 0;
    _totalMeters = points.totalDistance();

    // Drop the placeholder position so directions and progress are worked
    // out from the user's real location (shows "Acquiring GPS…" until then)
    currWalkingPos = null;

    length = leg_in.duration;
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
      ),
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

  String getFixedTitle() {
    return "Demo fixed title!";
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
    required this.lineType,
  });

  @override
  Color getColor() {
    // Return a random color
    // return Color(this.favoriteNumber.hashCode | 0xFF000000); // Return a color derived from this.favoriteNumber
    return color;
  }

  @override
  List<Marker> getMarkers() {
    return [
      Marker(
        markerId: MarkerId(
          "${this.favoriteNumber}-${this.startPoint.latitude}-${this.startPoint.longitude}",
        ),
        position: this.startPoint,
      ),
      Marker(
        markerId: MarkerId(
          "${this.favoriteNumber}-${this.endPoint.latitude}-${this.endPoint.longitude}",
        ),
        position: this.endPoint,
      ),
    ];
  }

  @override
  List<Polyline> getPolylines() {
    return [
      Polyline(
        polylineId: PolylineId(
          "${this.favoriteNumber}-${this.startPoint.latitude}-${this.startPoint.longitude}",
        ),
        points: [this.startPoint, this.endPoint],
        color: this.getColor(),
      ),
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
        lineType: this.lineType,
      ),
      NavigationStageStep(
        title: favoriteNumber == 3
            ? "Step 2 I'm making this title really long to test text wrapping. It's getting even longer now--practically absurd for the name of a bus stop but great for UI testing. "
            : "Step 2",
        subtitle: "Step 2 subtitle",
        time: '4:56 AM',
        color: getColor(), // Use the stage's color in our demo
        // lineType: LineType.Dashed,
        lineType: this.lineType,
      ),
      NavigationStageStep(
        title: "Step 3",
        subtitle: "Step 3 subtitle",
        time: '7:89 AM',
        color: getColor(), // Use the stage's color in our demo
        // lineType: LineType.Dashed,
        lineType: this.lineType,
      ),
    ]; // Get navigation stage steps
  }

  bool hasRoundedCorners() {
    return favoriteNumber == 2;
  }

  final _eventController = StreamController<StageEvent>();

  Stream<StageEvent> get events => _eventController
      .stream; // This is so the NavigationController can do yourStage.events and access your event controller

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

  void receiveLocationUpdate(Position p) {
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
    required this.color,
  });
}

class TimelineInfo {
  List<TimelineStep> timelineSteps = [];
  double activePositionPercentage =
      0.0; // e.g. if the user is 31% of the way through the whole trip, this equals 0.31
  TimelineInfo({
    List<TimelineStep>? timelineSteps,
    this.activePositionPercentage = 0.0,
  }) : timelineSteps = timelineSteps ?? [];
}

class NavigationManager {
  // TODO: Implement ChangeNotifier and learn how that works

  NavigationManager({StopPredictionFetcher? fetchStopPredictions})
    : _fetchStopPredictions = fetchStopPredictions ?? fetchStopData;

  // All stages subscribed and we listen to all of them
  // Its the hivemind..........
  final List<StreamSubscription<StageEvent>> _stageSubs = [];

  // Prevents gps fix stream when navigation inactive
  bool _active = false;

  // start stop counts (for nav)
  int _session = 0;

  Position? _lastPosition;

  // Kept from initFromJourney so reroute() can plan and start again by itself
  LatLng? _destination;
  Color _walkingLineColor = Colors.black; // do we need to change this? 

  // The current journey's planned arrival, in seconds after midnight UTC
  int _arrivalSeconds = 0;

  // ETA
  DateTime? get arrivalTime {
    final bool busAhead = stageList.skip(currentStage).any(
      (stage) => stage is NavOnBus,
    );
    if (_active && !busAhead) {
      double secondsLeft = 0;
      for (int i = currentStage; i < stageList.length; i++) {
        final NavigationStage stage = stageList[i];
        final double fractionLeft = i == currentStage
            ? 1 - stage.percent_complete
            : 1;
        secondsLeft += stage.length * fractionLeft;
      }
      return DateTime.now().add(Duration(seconds: secondsLeft.round()));
    }
    return _arrivalSeconds == 0
        ? null
        : serviceSecondsToDateTime(_arrivalSeconds);
  }

  // Overlay reads this
  MissedBusInfo? missedBusPrompt;
  int? _promptStageIndex;

  bool isRerouting = false;
  String? rerouteError;

  bool isFinished = false; // Nav done!

  // Code below for the live "bus arriving in mere moments"

  final StopPredictionFetcher _fetchStopPredictions;

  // How often the upcoming bus's live prediction is fetched
  static const Duration _arrivalPollInterval = Duration(seconds: 30);

  // is the live prediction stale? 
  static const Duration _livePredictionMaxAge = Duration(minutes: 2);

  Timer? _arrivalPoll;
  ({int session, int stageIndex, DateTime arrivesAt, DateTime fetchedAt})?
  _livePrediction;
  int? _polledStageIndex; // so a newly upcoming bus is fetched right away

  /// Index of the bus stage the card is about: the current stage if it's a
  /// bus the user hasn't left on yet, or the next one if they're walking to
  /// it. Null otherwise (riding, last walk, finished, or prompt showing), so
  /// (if) after a transfer the card comes back on the walk to the next bus.
  int? get _upcomingBusIndex {
    if (!_active || isFinished || missedBusPrompt != null) return null;
    for (int i = currentStage; i <= currentStage + 1; i++) {
      if (i >= stageList.length) return null;
      final NavigationStage stage = stageList[i];
      if (stage is NavOnBus) return stage.departed ? null : i;
      if (stage is! Walking) return null;
    }
    return null;
  }

  // bus info of bus to be displayed 
  UpcomingBusInfo? get upcomingBus {
    final int? index = _upcomingBusIndex;
    if (index == null) return null;
    final NavOnBus bus = stageList[index] as NavOnBus;

    final live = _livePrediction;
    final bool liveIsFresh =
        live != null &&
        live.session == _session &&
        live.stageIndex == index &&
        DateTime.now().difference(live.fetchedAt) < _livePredictionMaxAge;

    return UpcomingBusInfo(
      routeId: bus.routeId,
      stopId: bus.boardingStopId,
      stopName: getStopNameFromID(bus.boardingStopId),
      arrivesAt: liveIsFresh ? live.arrivesAt : bus.scheduledDeparture,
      live: liveIsFresh,
    );
  }

  void _startArrivalPolling() {
    _arrivalPoll?.cancel();
    _livePrediction = null;
    _polledStageIndex = null;
    _arrivalPoll = Timer.periodic(
      _arrivalPollInterval,
      (_) => unawaited(_refreshLivePrediction()),
    );
    unawaited(_refreshLivePrediction());
  }

  void _stopArrivalPolling() {
    _arrivalPoll?.cancel();
    _arrivalPoll = null;
    _livePrediction = null;
    _polledStageIndex = null;
  }

  // called when upcoming bus might have changed due to a bus transfer etc. 
  void _pollIfUpcomingBusChanged() {
    if (_arrivalPoll == null) return;
    final int? index = _upcomingBusIndex;
    if (index != null && index != _polledStageIndex) {
      unawaited(_refreshLivePrediction());
    }
  }

  Future<void> _refreshLivePrediction() async {
    final int? index = _upcomingBusIndex;
    if (index == null) return;
    final NavOnBus bus = stageList[index] as NavOnBus;
    final int session = _session;
    _polledStageIndex = index;

    final List<BusWithPrediction> predictions;
    try {
      predictions = await _fetchStopPredictions(bus.boardingStopId);
    } catch (e) {
      // Offline or the feed is down: the card falls back to the timetable
      // once the last prediction gets too old
      stderr.writeln("Couldn't fetch arrivals for ${bus.boardingStopId}: $e");
      return;
    }
    // Navigation stopped, restarted, or moved on while we were waiting
    if (session != _session || _upcomingBusIndex != index) return;

    final DateTime now = DateTime.now();
    final int? minutes = soonestPredictionMinutes(
      predictions,
      routeId: bus.routeId,
      vehicleId: bus.plannedVehicleId,
    );
    final DateTime? previous = _livePrediction?.arrivesAt;
    _livePrediction = minutes == null
        ? null
        : (
            session: session,
            stageIndex: index,
            arrivesAt: now.add(Duration(minutes: minutes)),
            fetchedAt: now,
          );
    if (_livePrediction?.arrivesAt != previous) notifyOverlay();
  }

  int currentStage = 0; // Stores the current navigation state index
  List<NavigationStage> stageList = [
    DemoStage(
      favoriteNumber: 1,
      length: 15,
      percent_complete: 0.80,
      startPoint: LatLng(42.281973, -83.765719),
      endPoint: LatLng(42.281291, -83.743918),
      color:
          darkColors[ColorType
              .navigationStepsGray]!, // TODO: Make this dynamic. This will be messy since we need to do something about context in getColor(context, color Type)
      lineType: LineType.Dashed,
    ),
    DemoStage(
      favoriteNumber: 2,
      length: 33,
      percent_complete: 0.23,
      startPoint: LatLng(42.281291, -83.743918),
      endPoint: LatLng(42.287031, -83.743532),
      color: Colors.purple,
      lineType: LineType.Dotted,
    ),
    DemoStage(
      favoriteNumber: 3,
      length: 4,
      percent_complete: 0.0,
      startPoint: LatLng(42.287031, -83.743532),
      endPoint: LatLng(42.289689, -83.738435),
      color: darkColors[ColorType.navigationStepsGray]!,
      lineType: LineType.Dashed,
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

  // Overlay redraw interval
  static const Duration _liveRefreshInterval = Duration(seconds: 1);
  DateTime? _lastLiveRefresh;

  void receiveLocationUpdate(Position p) {
    _lastPosition = p;
    if (!_active) return;
    _forwardPosition(p);

    // The overlay only re-reads the timeline (and so each stage's
    // percent_complete) when told to, so tell it now and then to keep the
    // header and progress dot moving between stage changes.
    final DateTime now = DateTime.now();
    final DateTime? last = _lastLiveRefresh;
    if (last == null || now.difference(last) >= _liveRefreshInterval) {
      _lastLiveRefresh = now;
      notifyOverlay();
    }
  }

  // forward pos info to the actually active stage
  void _forwardPosition(Position p) {
    stageList[currentStage].receiveLocationUpdate(p);
    if (currentStage < stageList.length - 1) {
      final NavigationStage next = stageList[currentStage + 1];
      if (next is NavOnBus) next.receiveLocationUpdate(p);
    }
  }

  // Call to update if state changes require an update
  void notifyOverlay() {
    _overlay?.onNavigationUpdated();
  }

  // TESTING ONLY!!! Emulates departure from boarding radius
  // DO NOT USE NORMALLY IT WILL FORCE DIALOGUE
  void debugForceLeftStop() {
    for (int i = currentStage; i <= currentStage + 1 && i < stageList.length; i++) {
      final stage = stageList[i];
      if (stage is NavOnBus) {
        stage.debugForceLeftStop();
        return;
      }
    }
  }

  void _onStageEvent(NavigationStage stage, StageEvent event) {
    // -1 means a stage from a journey we've since replaced
    final int index = stageList.indexOf(stage);
    if (index == -1 || !_active) return;

    switch (event) {
      case StageComplete():
        // Exception accounted for: reaching the end of the bus ride while we still have the user walking to the stop
        if (index == currentStage ||
            (index == currentStage + 1 && stage is NavOnBus)) {
          _advanceTo(index + 1);
        }
      case StageLeftStop(:final info):
        if (index >= currentStage && missedBusPrompt == null) {
          _setPrompt(info, index);
          notifyOverlay();
        }
      case StageReroute(:final reason):
        unawaited(reroute(reason));
    }
  }

  /// Moves forward to stage index or finishes, CANNOT MOVE BACK
  void _advanceTo(int index) {
    if (isFinished || index <= currentStage) return;

    if (index >= stageList.length) {
      currentStage = stageList.length - 1;
      isFinished = true;
    } else {
      currentStage = index;
    }

    // Did you fade answering the prompt? (If so it'll get rid of it)
    final int? promptIndex = _promptStageIndex;
    if (promptIndex != null && promptIndex < currentStage) _setPrompt(null);

    notifyOverlay();

    // The newly current stage hasn't heard where the user is yet
    final Position? p = _lastPosition;
    if (!isFinished && p != null) _forwardPosition(p);

    // eg. got off one bus and now walking to the next
    _pollIfUpcomingBusChanged();
  }

  void _setPrompt(MissedBusInfo? info, [int? stageIndex]) {
    if (info == null && missedBusPrompt == null) return;
    missedBusPrompt = info;
    _promptStageIndex = info == null ? null : stageIndex;
    if (info == null) {
      _overlay?.clearMissedBusPrompt();
    } else {
      _overlay?.displayMissedBusPrompt(info);
    }
  }

  // User confirmed in prompt that they are on the bus
  void confirmBoarded() {
    final int? promptIndex = _promptStageIndex;
    if (promptIndex != null) _advanceTo(promptIndex);
    _setPrompt(null);
    notifyOverlay();
  }

  static const Duration _rerouteTimeout = Duration(seconds: 15);

  // User needs to reroute, they clicked the button
  Future<void> reroute([RerouteReason reason = RerouteReason.missedBus]) async {
    if (isRerouting || !_active) return;
    final int session = _session;
    isRerouting = true;
    rerouteError = null;
    notifyOverlay();

    List<Journey>? journeys;
    String? error;
    try {
      final LatLng? destination = _destination;
      final Position? origin =
          _lastPosition ?? await Geolocator.getLastKnownPosition();
      if (destination == null) {
        error = "Can't reroute without a destination";
      } else if (origin == null) {
        error = "Waiting for GPS…";
      } else {
        journeys = await JourneyRepository.planJourney(
          originLat: origin.latitude,
          originLon: origin.longitude,
          destLat: destination.latitude,
          destLon: destination.longitude,
        ).timeout(_rerouteTimeout);
      }
    } catch (_) {
      error = "Couldn't get a new route";
    }

    // User deliberately exited
    if (session != _session) return;

    isRerouting = false;
    if (journeys != null && !_startBestJourney(journeys)) {
      error = "No other routes right now";
    }
    rerouteError = error;
    notifyOverlay();
  }

  // Earliest doable journey, or if none is possible
  bool _startBestJourney(List<Journey> journeys) {
    // A bus that's already gone (or about to be) would just ask again
    final DateTime catchableAfter = DateTime.now().add(
      const Duration(seconds: 60),
    );
    final candidates =
        journeys.where((journey) {
          // 0 means missing (Journey.fromJson defaults it)
          if (journey.arrivalTime == 0) return false;
          final DateTime? departure = _firstBusDeparture(journey);
          return departure == null || !departure.isBefore(catchableAfter);
        }).toList()..sort(
          (a, b) => serviceSecondsToDateTime(
            a.arrivalTime,
          ).compareTo(serviceSecondsToDateTime(b.arrivalTime)),
        );

    for (final journey in candidates) {
      if (initFromJourney(journey, _walkingLineColor)) return true;
    }
    return false;
  }

  // When the journey's first bus leaves its stop, or null if it has no bus
  static DateTime? _firstBusDeparture(Journey journey) {
    for (final leg in journey.legs) {
      final Trip? trip = leg.trip;
      if (leg.mode != LegMode.bus || trip == null) continue;
      for (final st in trip.stopTimes) {
        if (st.stop == leg.originID) {
          return serviceSecondsToDateTime(st.departureTime);
        }
      }
      return null;
    }
    return null;
  }

  // Ends navigation 
  // Keeps old stages in order to prevent a overlay redraw from going bad
  void stop() {
    _active = false;
    _session++;
    _stopArrivalPolling();
    _teardownStages();
    _setPrompt(null);
    isRerouting = false;
    rerouteError = null;
  }

  // Cancelling first also drops any event still on its way from a stage
  void _teardownStages() {
    for (final sub in _stageSubs) {
      sub.cancel();
    }
    _stageSubs.clear();
    for (final stage in stageList) {
      stage.dispose();
    }
  }

  void setMapLayer(NavigationLayer mapLayer_in) {
    this.mapLayer = mapLayer_in;
    rebuildMarkersAndPolylines();
  }

  TimelineInfo getTimeline() {
    // TODO: Also return the user's position in the whole journey

    double total_estimated_time = 0.0;
    double activePositionTime =
        0.0; // This is the active position percentage before dividing by total estimated trip length
    double activePositionPercentage = 0.0;

    for (int i = 0; i < stageList.length; i++) {
      double currentStageLength = stageList[i].length;

      total_estimated_time += currentStageLength;

      if (i < currentStage) {
        activePositionTime = activePositionTime + currentStageLength;
      } else if (i == currentStage) {
        activePositionTime +=
            currentStageLength * stageList[i].percent_complete;
      }
    }
    // Bad data (eg. every stage 0 long) must not reach the overlay as NaN:
    // the progress bar can't lay that out
    activePositionPercentage = total_estimated_time > 0
        ? activePositionTime / total_estimated_time
        : 0.0;
    if (!activePositionPercentage.isFinite) activePositionPercentage = 0.0;
    activePositionPercentage = activePositionPercentage.clamp(0.0, 1.0);

    List<TimelineStep> timelineSteps = [];

    for (int i = 0; i < stageList.length; i++) {
      timelineSteps.add(
        TimelineStep(
          estimated_time: stageList[i].length,
          percentage: total_estimated_time > 0
              ? stageList[i].length / total_estimated_time
              : 0.0,
          color: stageList[i].getColor(),
          // TODO: Define a color for the stage in the stage itself
          // color: Colors.red
        ),
      );
    }

    return TimelineInfo(
      timelineSteps: timelineSteps,
      activePositionPercentage: activePositionPercentage,
    );
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

  void rebuildMarkersAndPolylines() {
    // Call this whenever markers or polylines change
    if (this.mapLayer == null) {
      stderr.writeln(
        "Warning: Tried to rebuild markers and polylines but no map layer was registered with NavigationManager!",
      );
      return;
    }
    Set<Marker> markersToDisplay = stageList
        .expand((NavigationStage stage) => stage.getMarkers())
        .toSet();
    Set<Polyline> polylinesToDisplay = stageList
        .expand((NavigationStage stage) => stage.getPolylines())
        .toSet();

    this.mapLayer!.setMarkers(markersToDisplay);
    this.mapLayer!.setPolylines(polylinesToDisplay);
    this.mapLayer!.reload();

    // FUTURE TODO: Get some sample data for polylines/markers and conditionally show them on the map--define a "navigation mode" that can be active (or not) in map_screen.dart
  }

  NavigationStage getCurrentStage() {
    return stageList[currentStage];
  }

  // Stops at the ends rather than wrapping around
  void nextStage() {
    _advanceTo(currentStage + 1);
  }

  void previousStage() {
    if (currentStage == 0) return;
    currentStage--;
    isFinished = false;
    notifyOverlay();
  }

  /// Starts navigating [journey]. Returns false, leaving whatever was running
  /// untouched, if a stage can't be built from it (eg. a stop with no
  /// coordinates).
  bool initFromJourney(
    Journey journey,
    Color walkingLineColor, {
    LatLng? destination,
  }) {
    // Build everything before touching the current stages: a reroute must
    // never be able to wreck the navigation it's replacing.
    final List<NavigationStage> stages = [];
    try {
      for (Leg leg in journey.legs) {
        if (leg.mode == LegMode.walk) {
          Walking walkingStage = Walking();
          walkingStage.setColor(
            walkingLineColor,
          ); // Because Flutter won't let us get a Context inside WalkingStage because it isn't a widget. Womp womp
          walkingStage.initWithLeg(leg);
          stages.add(walkingStage);
        } else if (leg.mode == LegMode.bus) {
          NavOnBus onBusStage = NavOnBus();
          onBusStage.initWithLeg(leg);
          stages.add(onBusStage);
        }
      }
    } catch (e) {
      stderr.writeln("Couldn't start navigation for this journey: $e");
      for (final stage in stages) {
        stage.dispose();
      }
      return false;
    }
    if (stages.isEmpty) return false;

    _teardownStages();
    stageList = stages;
    currentStage = 0;
    _session++;
    isFinished = false;
    rerouteError = null;
    _setPrompt(null);
    _walkingLineColor = walkingLineColor;
    _arrivalSeconds = journey.arrivalTime;
    if (destination != null) _destination = destination;

    // Subscribe before anything can emit, drop events that have no listeners
    for (final stage in stageList) {
      _stageSubs.add(
        stage.events.listen((event) => _onStageEvent(stage, event)),
      );
    }
    _active = true;
    _startArrivalPolling();

    _overlay?.onNavigationUpdated();
    rebuildMarkersAndPolylines();

    // The user may already be where a stage ends (eg. at the stop), and won't
    // get a new fix until they move.
    final Position? p = _lastPosition;
    if (p != null) _forwardPosition(p);
    return true;
  }
}

abstract class NavigationOverlayHost {
  void displayMissedBusPrompt(MissedBusInfo info);
  void clearMissedBusPrompt();
  void onNavigationUpdated(); // call navigation overlay widget to refresh
}
