class Journey {
  final List<Leg> legs;
  final int departureTime;
  final int arrivalTime;

  Journey({required this.legs, required this.departureTime, required this.arrivalTime});

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      legs: (json['legs'] as List).map((e) => Leg.fromJson(e)).toList(),
      departureTime: json['departureTime'] ?? 0,
      arrivalTime: json['arrivalTime'] ?? 0,
    );
  }
}

class Leg {
  final String origin;
  final String destination;
  final int duration;
  final int startTime;
  final int endTime;
  final List<StopTime>? stopTimes;
  final Trip? trip;
  final String? rt;
  final String originID;
  final String destinationID;

  Leg({
    required this.origin,
    required this.destination,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.stopTimes,
    this.trip,
    this.rt,
    required this.originID,
    required this.destinationID
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      duration: json['duration'] ?? 0,
      startTime: json['startTime'] ?? 0,
      endTime: json['endTime'] ?? 0,
      stopTimes: json['stopTimes'] != null
          ? (json['stopTimes'] as List).map((e) => StopTime.fromJson(e)).toList()
          : null,
      trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
      rt: json['rt'],
      originID: json['origin_id'] ?? '',
      destinationID: json['destination_id'] ?? ''
    );
  }
}

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

  factory StopTime.fromJson(Map<String, dynamic> json) {
    return StopTime(
      stop: json['stop'] ?? '',
      arrivalTime: json['arrivalTime'] ?? 0,
      departureTime: json['departureTime'] ?? 0,
      pickUp: json['pickUp'] ?? false,
      dropOff: json['dropOff'] ?? false,
    );
  }
}

class Trip {
  final String tripId;
  final List<StopTime> stopTimes;

  Trip({required this.tripId, required this.stopTimes});

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['tripId'] ?? '',
      stopTimes: (json['stopTimes'] as List).map((e) => StopTime.fromJson(e)).toList(),
    );
  }
}