import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

/// Function to calculate rotation angle between two geographical points
/// (used for bus stop icon orientation)
double pointRotation(double lat1, double lon1, double lat2, double lon2) {
  double dLat = lat2 - lat1;
  double dLon = lon2 - lon1;

  // Scale longitude by cos(lat) to correct for east-west distance
  double x = dLon * (cos(lat1 * degrees2Radians));
  double y = dLat;

  double angle = atan2(x, y) * radians2Degrees;

  // Normalize to [0, 360)
  if (angle < 0) angle += 360;

  return angle;
}

double routeStopRotation(List<dynamic> points, int stopIndex) {
  final currentStop = points[stopIndex];

  (double, double) averageLocation(List<dynamic> stops) {
    final locations = stops.isEmpty ? [currentStop] : stops;
    // find sum of lat/lng and divide by the amount to get average
    final latitude =  locations.fold<double>(0, (sum, stop) => sum + (stop['lat']?.toDouble() ?? 0)) / locations.length;
    final longitude = locations.fold<double>(0, (sum, stop) => sum + (stop['lon']?.toDouble() ?? 0)) / locations.length;
    return (latitude, longitude);
  }

  // deal with edge cases at start/end of list by reading next four or previous four points
  if (stopIndex >= points.length - 2) {
    final prevTwo = averageLocation(points.getRange(stopIndex - 2, stopIndex).toList());
    final prevFour = averageLocation(points.getRange(stopIndex - 4, stopIndex - 2).toList());
    return pointRotation(prevTwo.$1, prevTwo.$2, prevFour.$1, prevFour.$2);
  } else if (stopIndex <= 2) {
    final nextTwo = averageLocation(points.getRange(stopIndex + 1, stopIndex + 3).toList());
    final nextFour = averageLocation(points.getRange(stopIndex + 3, stopIndex + 5).toList());
    return pointRotation(nextTwo.$1, nextTwo.$2, nextFour.$1, nextFour.$2);
  }

  final stopsRange = 2;

  // get rotation from the average of the previous stopsRange stops to the average location of the next 3 stops
  final previousStops = points
      .take(stopIndex).toList()
      .reversed
      .take(stopsRange).toList();
  final nextStops = points
      .skip(stopIndex + 1)
      .take(stopsRange).toList();

  final previous = averageLocation(previousStops);
  final next = averageLocation(nextStops);

  return pointRotation(previous.$1, previous.$2, next.$1, next.$2);
}

extension LatLngListHelpers on List<LatLng> {
  double totalDistance() {
    double acc = 0.0;
    LatLng? prev;
    for (final next in this) {
      if (prev != null) acc += prev.haversineDistanceMetersTo(next);
      prev = next;
    }
    return acc;
  }
}

extension Vector3GeometryHelpers on Vector3 {
  /// expects [this] to be in the same coordinate system used by [LatLng.toEuclideanUnitSphere()]
  LatLng toLatLng() {
    return LatLng(
      (180.0 - acos(z) * radians2Degrees) - 90.0,
      atan2(y, x) * radians2Degrees,
    );
  }
}

extension LatLngGeometryHelpers on LatLng {
  Vector3 toEuclideanUnitSphere() {
    final phi = (180.0 - (latitude + 90.0)) * degrees2Radians;
    final theta = longitude * degrees2Radians;
    return Vector3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
  }

  /// Haversine distance to `other` in meters
  double haversineDistanceMetersTo(LatLng other) {
    const R = 6371000; // Earth radius in meters
    final lat1 = latitude * degrees2Radians;
    final lat2 = other.latitude * degrees2Radians;
    final dLat = (other.latitude - latitude) * degrees2Radians;
    final dLon = (other.longitude - longitude) * degrees2Radians;

    final sa =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return R * c;
  }

  /// Finds the nearest point in the list [poly], returning an index and distance.
  (int, double) nearestPolylineIndexAndDistanceDiscrete(List<LatLng> poly) {
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < poly.length; i++) {
      final p = poly[i];
      final d = haversineDistanceMetersTo(p);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return (bestIdx, bestDist);
  }

  /// Returns the closest point on the great circle containing [a] and [b] in euclidean
  Vector3 projectedToGreatCircle(LatLng a, LatLng b) {
    final point = toEuclideanUnitSphere();
    point.applyProjection(
      makePlaneProjection(
        a.toEuclideanUnitSphere().cross(b.toEuclideanUnitSphere()),
        Vector3.zero(),
      ),
    );
    return point.normalized();
  }

  /// Returns the closest point on the geodesic between [a] and [b]
  LatLng projectedToSegment(LatLng a, LatLng b) {
    final aEuc = a.toEuclideanUnitSphere();
    final bEuc = b.toEuclideanUnitSphere();
    final thisEucGreatCirc = projectedToGreatCircle(a, b);

    // this would break if you were on the other side of the globe, which should be fine
    final notPastA = (bEuc - aEuc).dot(thisEucGreatCirc - aEuc) >= 0.0;
    final notPastB = (aEuc - bEuc).dot(thisEucGreatCirc - bEuc) >= 0.0;
    if (notPastA && notPastB) {
      return thisEucGreatCirc.toLatLng();
    }

    final aDist = haversineDistanceMetersTo(a);
    final bDist = haversineDistanceMetersTo(b);
    if (aDist <= bDist) {
      return a;
    } else {
      return b;
    }
  }

  /// Finds the nearest point on [poly], treating it as a continuous polyline.
  ///
  /// Returns an index and distance
  ///
  /// WARNING: hasn't been tested yet, might be buggy
  (double, double) nearestPolylineIndexAndDistanceContinuous(
    List<LatLng> poly,
  ) {
    if (poly.isEmpty) {
      return (0.0, double.infinity);
    }
    if (poly.length == 1) {
      return (0.0, haversineDistanceMetersTo(poly[0]));
    }
    var bestIdx = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < poly.length - 1; i++) {
      final projected = projectedToSegment(poly[i], poly[i + 1]);
      final distance = haversineDistanceMetersTo(projected);
      if (distance < bestDistance) {
        bestDistance = distance;
        var segmentLength = poly[i].haversineDistanceMetersTo(poly[i + 1]);
        if (segmentLength == 0.0) {
          segmentLength = double.infinity;
        }
        bestIdx = i + poly[i].haversineDistanceMetersTo(projected) / segmentLength;
      }
    }
    return (bestIdx, bestDistance);
  }
}
