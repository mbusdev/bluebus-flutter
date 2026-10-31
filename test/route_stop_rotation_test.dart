import 'package:bluebus/utils/geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A straight line of points heading due north.
List<LatLng> _northbound(int count) => [
  for (var i = 0; i < count; i++) LatLng(42.28 + i * 0.001, -83.74),
];

void main() {
  group('routeStopRotation', () {
    test('middle of a long route points along the route', () {
      final points = _northbound(10);
      expect(routeStopRotation(points, 5), closeTo(0, 1e-6));
    });

    test('stop near the start of a long route does not throw', () {
      final points = _northbound(10);
      for (final i in [0, 1, 2]) {
        expect(() => routeStopRotation(points, i), returnsNormally);
      }
    });

    test('stop near the end of a long route does not throw', () {
      final points = _northbound(10);
      for (final i in [7, 8, 9]) {
        expect(() => routeStopRotation(points, i), returnsNormally);
      }
    });

    // The parsers call routeStopRotation for every stop point, and catch any
    // exception by dropping the whole subroute. Short routes must not throw.
    for (var count = 1; count <= 5; count++) {
      test('every stop index in a $count-point route does not throw', () {
        final points = _northbound(count);
        for (var i = 0; i < count; i++) {
          expect(
            () => routeStopRotation(points, i),
            returnsNormally,
            reason: 'stopIndex $i of $count points',
          );
        }
      });
    }

    test('result is a valid angle in [0, 360)', () {
      final points = _northbound(10);
      for (var i = 0; i < points.length; i++) {
        final angle = routeStopRotation(points, i);
        expect(angle, inInclusiveRange(0, 360));
        expect(angle.isNaN, isFalse);
      }
    });
  });
}
