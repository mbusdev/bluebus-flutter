import 'dart:async';

import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_layers/base_routes_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

BusStop _stop(String id, String routeId, double lat, double lon) => BusStop(
  id: id,
  name: 'Stop $id',
  location: LatLng(lat, lon),
  routeId: routeId,
  rotation: 0,
  isRide: false,
);

BusRouteLine _route(String routeId, double lat, List<BusStop> stops) =>
    BusRouteLine(
      routeId: routeId,
      color: Colors.red,
      points: [
        for (var i = 0; i < 6; i++) LatLng(lat + i * 0.001, -83.74 + i * 0.001),
      ],
      stops: [
        for (var i = 0; i < stops.length; i++) (i + 1, stops[i]),
      ],
    );

/// Fake network:
///   A: stops A1 and SHARED
///   B: stops B1 and SHARED
///   C: stop C1
List<BusRouteLine> _fakeRoutes() {
  final sharedA = _stop('SHARED', 'A', 42.290, -83.730);
  final sharedB = _stop('SHARED', 'B', 42.290, -83.730);
  return [
    _route('A', 42.280, [_stop('A1', 'A', 42.281, -83.739), sharedA]),
    _route('B', 42.300, [_stop('B1', 'B', 42.301, -83.739), sharedB]),
    _route('C', 42.320, [_stop('C1', 'C', 42.321, -83.739)]),
  ];
}

Set<String> _stopIds(BaseRoutesLayer layer) => layer.markers
    .map((m) => m.markerId.value.split('_')[1]) // stop_<id>_<routeKey>
    .toSet();

Set<String> _polylineRouteIds(BaseRoutesLayer layer) =>
    layer.polylines.map((p) => p.polylineId.value.split('_').first).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BaseRoutesLayer layer;
  late int updates;
  late Completer<void> nextUpdate;

  Future<void> waitForUpdate() async {
    await nextUpdate.future.timeout(const Duration(seconds: 20));
    nextUpdate = Completer<void>();
  }

  /// Builds a layer with [selected] routes, loads the fake network, and waits
  /// for the initial (async) marker generation to settle.
  Future<void> setUpLayer(
    Set<String> selected, {
    Set<String> favorites = const {},
  }) async {
    updates = 0;
    nextUpdate = Completer<void>();
    layer = BaseRoutesLayer();
    layer.setOnUpdate(() {
      updates++;
      if (!nextUpdate.isCompleted) nextUpdate.complete();
    });
    layer.init(favorites, selected, (_) {});
    layer.cacheRoutes(_fakeRoutes());
    // cacheRoutes notifies once after polylines and once after markers
    while (updates < 2) {
      await waitForUpdate();
    }
  }

  /// reload() is fire-and-forget, so wait for the onUpdate it ends with.
  Future<void> reload() async {
    nextUpdate = Completer<void>();
    layer.reload();
    await waitForUpdate();
  }

  test('only selected routes get markers and polylines', () async {
    await setUpLayer({'A', 'C'});
    await reload();

    expect(_polylineRouteIds(layer), {'A', 'C'});
    expect(_stopIds(layer), {'A1', 'SHARED', 'C1'});
  });

  test('deselected routes render nothing', () async {
    await setUpLayer({});
    await reload();

    expect(layer.polylines, isEmpty);
    expect(layer.markers, isEmpty);
  });

  test('selection changes take effect on the next reload()', () async {
    await setUpLayer({'A'});
    await reload();
    expect(_stopIds(layer), {'A1', 'SHARED'});

    layer.selectedRoutes = {'C'};
    await reload();
    expect(_polylineRouteIds(layer), {'C'});
    expect(_stopIds(layer), {'C1'});
  });

  group('stop shared between routes A and B', () {
    test('shows when only A is enabled', () async {
      await setUpLayer({'A'});
      await reload();

      expect(_stopIds(layer), contains('SHARED'));
      expect(_stopIds(layer), isNot(contains('B1')));
    });

    test('shows when only B is enabled', () async {
      await setUpLayer({'B'});
      await reload();

      expect(_stopIds(layer), contains('SHARED'));
      expect(_stopIds(layer), isNot(contains('A1')));
    });

    test('shows once, not duplicated, when both are enabled', () async {
      await setUpLayer({'A', 'B'});
      await reload();

      expect(_stopIds(layer), {'A1', 'B1', 'SHARED'});
      expect(
        layer.markers.where((m) => m.markerId.value.contains('SHARED')),
        hasLength(1),
      );
    });

    test('disappears when neither is enabled', () async {
      await setUpLayer({'C'});
      await reload();

      expect(_stopIds(layer), {'C1'});
    });

    test('cacheRoutes records every route serving the shared stop', () async {
      await setUpLayer({'A'});

      expect(layer.stopIdToRouteIds['SHARED'], {'A', 'B'});
      expect(layer.stopIdToRouteIds['A1'], {'A'});
    });
  });

  test('favorite stops still render', () async {
    await setUpLayer({'A'}, favorites: {'A1'});
    await reload();

    expect(_stopIds(layer), {'A1', 'SHARED'});
  });
}
