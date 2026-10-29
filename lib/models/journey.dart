import 'package:bluebus/models/lat_lng.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bluebus/backend/export.dart' as backend;

class Journey {
  final List<Leg> legs;
  final int departureTime;
  final int arrivalTime;

  Journey({required this.legs, required this.departureTime, required this.arrivalTime});

  factory Journey.fromBackend(backend.ProcessedJourney journey) {
    return Journey(
      legs: journey.legs.map(Leg.fromBackend).toList(),
      departureTime: journey.departureTime.toInt(),
      arrivalTime: journey.arrivalTime.toInt(),
    );
  }
}

sealed class Leg {
  final String origin;
  final String destination;
  final String originID;
  final String destinationID;
  final double duration;
  final int startTime;
  final int endTime;

  Leg({
    required this.origin,
    required this.destination,
    required this.originID,
    required this.destinationID,
    required this.duration,
    required this.startTime,
    required this.endTime,
  });
  
  factory Leg.fromBackend(backend.FormattedLeg leg) {
    switch (leg) {
      case backend.FormattedLegFormattedLegWalk():
        return WalkingLeg.fromBackend(leg);
      case backend.FormattedLegFormattedLegBus():
        return BusLeg.fromBackend(leg);
    }
  }
}

class BusLeg extends Leg {
  final String destinationName;
  final List<({ String? rt, List<LatLng> path })> busPathSegments;
  final List<({ String? rt, LatLng location })> stopCoords;
  final String mode;
  final List<StopTime> stopTimes;
  final Trip trip;
  final String rt;
  final String? vid;

  BusLeg.fromBackend(backend.FormattedLegFormattedLegBus leg)
    : destinationName = leg.destinationName,
      busPathSegments = leg.busPathSegments
          .map((e) => (rt: e.rt, path: e.path.map(latLngFromBackend).toList()))
          .toList(),
      stopCoords = leg.stopCoords
          .map((e) => (rt: e.rt, location: latLngFromBackend(e.location)))
          .toList(),
      mode = leg.mode,
      stopTimes = leg.stopTimes.map((e) => StopTime.fromBackend(e)).toList(),
      trip = Trip.fromBackend(leg.trip),
      rt = leg.rt,
      vid = leg.vid,
      super(
        origin: leg.origin,
        destination: leg.destination,
        originID: leg.originId,
        destinationID: leg.destinationId,
        duration: leg.duration.toDouble(),
        startTime: leg.startTime.toInt(),
        endTime: leg.endTime.toInt(),
      );
}

class WalkingLeg extends Leg {
  final List<LatLng> pathCoords;
  // TODO: re-add turn by turn directions

  WalkingLeg.fromBackend(backend.FormattedLegFormattedLegWalk leg)
    : pathCoords = leg.pathCoords.map(latLngFromBackend).toList(),
      super(
        origin: leg.origin,
        destination: leg.destination,
        originID: leg.originId,
        destinationID: leg.destinationId,
        duration: leg.duration.toDouble(),
        startTime: leg.startTime.toInt(),
        endTime: leg.endTime.toInt(),
      );
    
}

typedef Turn = ({double degree, String landmark});

class StopTime {
  final String stop;
  final int arrivalTime;
  final int departureTime;
  final bool pickUp;
  final bool dropOff;

  StopTime({
    required this.stop,
    required this.arrivalTime,
    required this.departureTime,
    required this.pickUp,
    required this.dropOff,
  });

  factory StopTime.fromBackend(backend.StopTime st) {
    return StopTime(
      stop: st.stop,
      arrivalTime: st.arrivalTime.toInt(),
      departureTime: st.departureTime.toInt(),
      pickUp: st.pickUp,
      dropOff: st.dropOff,
    );
  }
}

class Trip {
  final String tripId;
  final String? vid;
  final List<StopTime> stopTimes;

  Trip({required this.tripId, required this.vid, required this.stopTimes});

  factory Trip.fromBackend(backend.Trip trip) {
    return Trip(
      tripId: trip.tripId,
      vid: trip.vid,
      stopTimes: trip.stopTimes.map((st) => StopTime.fromBackend(st)).toList(),
    );
  }
}