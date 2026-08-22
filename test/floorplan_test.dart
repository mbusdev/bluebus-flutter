import 'dart:math' as math;

import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/services/floorplan_service.dart';
import 'package:bluebus/services/map_layers/floorplans_layer.dart';
import 'package:bluebus/utils/floorplan_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Rough great-circle distance in meters, good enough to sanity check that a
/// building comes out building-sized.
double _metersBetween(LatLng a, LatLng b) {
  const double metersPerDegreeLatitude = 111320.0;
  final double meanLatitude = (a.latitude + b.latitude) / 2 * math.pi / 180;
  final double dy = (b.latitude - a.latitude) * metersPerDegreeLatitude;
  final double dx =
      (b.longitude - a.longitude) *
      metersPerDegreeLatitude *
      math.cos(meanLatitude);
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duderstadt floorplan', () {
    late GeoreferencedFloorplan source;
    late FloorplanFloor floor;
    late FloorplanProjection projection;

    setUpAll(() async {
      source = await FloorplanService.loadDuderstadt();
      floor = source.floorplan.floors.first;
      projection = FloorplanProjection.forFloor(
        floor,
        waypoint1: source.waypoint1,
        waypoint2: source.waypoint2,
      )!;
    });

    test('parses the asset', () {
      expect(source.floorplan.building, 'Duderstadt');
      expect(source.floorplan.floors, hasLength(1));
      expect(floor.walls, hasLength(919));
      expect(floor.rooms, hasLength(147));
      expect(floor.pois, hasLength(195));
      expect(floor.outline, hasLength(224));
    });

    test('projects each waypoint back onto its real world position', () {
      for (final (String type, LatLng expected) in [
        (FloorplanTypes.waypoint1, source.waypoint1),
        (FloorplanTypes.waypoint2, source.waypoint2),
      ]) {
        final FloorplanPoi poi = floor.findPoiByType(type)!;
        final LatLng actual = projection.toLatLng(poi.position);
        expect(actual.latitude, closeTo(expected.latitude, 1e-9));
        expect(actual.longitude, closeTo(expected.longitude, 1e-9));
      }
    });

    test('scale agrees with the floorplan\'s own pxPerMeter', () {
      // Project a known pixel distance and check it comes back the right size.
      const double sampleLengthPx = 1000.0;
      final double projectedMeters = _metersBetween(
        projection.toLatLng(Offset.zero),
        projection.toLatLng(const Offset(sampleLengthPx, 0)),
      );
      final double expectedMeters = sampleLengthPx / floor.pxPerMeter;
      expect(projectedMeters, closeTo(expectedMeters, expectedMeters * 0.05));
    });

    test('building footprint comes out building-sized and in Ann Arbor', () {
      final List<LatLng> outline = projection.toLatLngList(floor.outline);

      final double minLat = outline.map((p) => p.latitude).reduce(math.min);
      final double maxLat = outline.map((p) => p.latitude).reduce(math.max);
      final double minLng = outline.map((p) => p.longitude).reduce(math.min);
      final double maxLng = outline.map((p) => p.longitude).reduce(math.max);

      final double widthMeters = _metersBetween(
        LatLng(minLat, minLng),
        LatLng(minLat, maxLng),
      );
      final double heightMeters = _metersBetween(
        LatLng(minLat, minLng),
        LatLng(maxLat, minLng),
      );

      expect(widthMeters, inInclusiveRange(100, 250));
      expect(heightMeters, inInclusiveRange(50, 200));

      // North campus, within a couple hundred meters of the waypoints.
      expect(
        _metersBetween(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          source.waypoint1,
        ),
        lessThan(200),
      );
    });
  });

  group('FloorplansLayer', () {
    late FloorplansLayer layer;

    setUpAll(() async {
      layer = FloorplansLayer();
      await layer.load();
    });

    CameraPosition cameraAt(double zoom) =>
        CameraPosition(target: const LatLng(42.2912, -83.7167), zoom: zoom);

    void moveTo(double from, double to) =>
        layer.onCameraMove(cameraAt(from), cameraAt(to));

    test('draws only the footprint when zoomed out', () {
      moveTo(19.0, 15.0);
      expect(layer.polygons, hasLength(1));
      expect(layer.polylines, isEmpty);
      expect(layer.markers, isEmpty);
    });

    test('draws nothing at city-wide zoom', () {
      moveTo(15.0, 12.0);
      expect(layer.polygons, isEmpty);
      expect(layer.polylines, isEmpty);
      expect(layer.markers, isEmpty);
    });

    test('draws the full plan once zoomed in, without labels', () {
      moveTo(12.0, 18.0);
      // Base footprint plus every room.
      expect(layer.polygons, hasLength(1 + layer.activeFloor!.rooms.length));
      expect(layer.polylines, isNotEmpty);
      expect(layer.markers, isEmpty);
    });

    test('merges wall segments without dropping any', () {
      moveTo(15.0, 18.0);

      // Chaining should meaningfully reduce the object count...
      expect(layer.polylines.length, lessThan(919));
      // ...while still accounting for all 919 segments. A chain of n points
      // covers n - 1 segments.
      final int segmentsDrawn = layer.polylines.fold(
        0,
        (total, polyline) => total + polyline.points.length - 1,
      );
      expect(segmentsDrawn, 919);
    });

    test('adds room labels and POI icons at the deepest zoom', () {
      moveTo(18.0, 19.0);
      expect(layer.markers, isNotEmpty);

      final int labels = layer.markers
          .where((m) => m.markerId.value.startsWith('floorplan_label_'))
          .length;
      final int icons = layer.markers
          .where((m) => m.markerId.value.startsWith('floorplan_icon_'))
          .length;

      // 78 "room" POIs plus the one "food" POI get labels.
      expect(labels, 79);
      // Every POI with an icon assigned: 6 elevators, 6 stairways,
      // 2 escalators, 6 bathrooms, 1 food and 1 info.
      expect(icons, 22);
    });
  });
}
