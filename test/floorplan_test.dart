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
      expect(source.floorplan.floors, hasLength(2));

      expect(floor.name, 'Floor 1');
      expect(floor.walls, hasLength(919));
      expect(floor.rooms, hasLength(147));
      expect(floor.pois, hasLength(195));
      expect(floor.outline, hasLength(84));

      final FloorplanFloor basement = source.floorplan.floors[1];
      expect(basement.name, 'Basement');
      expect(basement.walls, hasLength(418));
      expect(basement.rooms, hasLength(76));
      expect(basement.pois, hasLength(78));
      expect(basement.outline, hasLength(33));
    });

    test('lands every floor on the same building', () {
      // The floors are drawn in their own pixel spaces at different scales, so
      // the only thing tying them together is the shared waypoint pair.
      for (final FloorplanFloor other in source.floorplan.floors) {
        final FloorplanProjection otherProjection = FloorplanProjection.forFloor(
          other,
          waypoint1: source.waypoint1,
          waypoint2: source.waypoint2,
        )!;

        for (final LatLng corner in otherProjection.toLatLngList(other.outline)) {
          expect(_metersBetween(corner, source.waypoint1), lessThan(200));
        }
      }
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

  group('Floor ordering', () {
    FloorplanFloor floorNamed(String name) => FloorplanFloor(
      id: name,
      name: name,
      pxPerMeter: 1.0,
      width: 0.0,
      height: 0.0,
      walls: const [],
      rooms: const [],
      pois: const [],
      outline: const [],
      nav: const FloorplanNavGraph(nodes: [], edges: []),
    );

    test('reads a level and a short label out of the floor name', () {
      expect(floorNamed('Floor 1').level, 1);
      expect(floorNamed('Floor 1').shortName, '1');

      expect(floorNamed('Floor 12').level, 12);
      expect(floorNamed('Floor 12').shortName, '12');

      expect(floorNamed('Basement').level, -1);
      expect(floorNamed('Basement').shortName, 'B');

      expect(floorNamed('B2').level, -2);
      expect(floorNamed('B2').shortName, 'B');
    });

    test('falls back to something harmless for an unreadable name', () {
      expect(floorNamed('Mezzanine').level, 0);
      expect(floorNamed('Mezzanine').shortName, 'M');
      expect(floorNamed('').level, 0);
      expect(floorNamed('').shortName, '?');
    });

    test('orders the real floors with the basement at the bottom', () async {
      final GeoreferencedFloorplan source =
          await FloorplanService.loadDuderstadt();
      final List<FloorplanFloor> ordered = [...source.floorplan.floors]
        ..sort((a, b) => b.level.compareTo(a.level));

      expect([for (final f in ordered) f.shortName], ['1', 'B']);
    });
  });

  group('FloorplansLayer floor switching', () {
    late FloorplansLayer layer;

    setUp(() async {
      layer = FloorplansLayer();
      await layer.load();
      // Zoom in far enough that the detailed plan is what's drawn.
      layer.onCameraMove(
        const CameraPosition(target: LatLng(42.2912, -83.7167), zoom: 15.0),
        const CameraPosition(target: LatLng(42.2912, -83.7167), zoom: 18.0),
      );
    });

    int segmentsDrawn() => layer.polylines.fold(
      0,
      (total, polyline) => total + polyline.points.length - 1,
    );

    test('starts on the first floor', () {
      expect(layer.activeFloor!.name, 'Floor 1');
      expect(segmentsDrawn(), 919);
    });

    test('swaps the drawn geometry when the basement is picked', () async {
      await layer.setFloorIndex(1);

      expect(layer.activeFloor!.name, 'Basement');
      expect(segmentsDrawn(), 418);
      expect(
        layer.polygons,
        hasLength(1 + layer.activeFloor!.rooms.length),
      );
      // Nothing from floor 1 should be left behind.
      expect(
        layer.polygons.where(
          (p) => p.polygonId.value.contains('n2b1-f34'),
        ),
        isEmpty,
      );
    });

    test('switches back to the first floor', () async {
      await layer.setFloorIndex(1);
      await layer.setFloorIndex(0);

      expect(layer.activeFloor!.name, 'Floor 1');
      expect(segmentsDrawn(), 919);
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
