import 'dart:convert';

import 'package:bluebus/bluebus_api.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/theride_api.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Processor =
    Future<List<BusRouteLine>> Function(
      String jsonBody,
      Function(String route, String error) onError,
    );

Map<String, dynamic> _waypoint(int i) => {
  'typ': 'W',
  'lat': 42.28 + i * 0.001,
  'lon': -83.74 + i * 0.001,
};

Map<String, dynamic> _stop(int i, String id) => {
  'typ': 'S',
  'stpid': id,
  'stpnm': 'Stop $id',
  'lat': 42.28 + i * 0.001,
  'lon': -83.74 + i * 0.001,
};

/// [count] points; any index in [stopAt] becomes a stop.
List<Map<String, dynamic>> _points(int count, {Set<int> stopAt = const {}}) => [
  for (var i = 0; i < count; i++)
    stopAt.contains(i) ? _stop(i, 'S$i') : _waypoint(i),
];

String _json(Map<String, List<Map<String, dynamic>>> routes) =>
    jsonEncode({'routes': routes});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final apis = <String, Processor>{
    'BlueBusApi': BlueBusApi.processRoutesJson,
    'RideAPI': RideAPI.processRoutesJson,
  };

  for (final entry in apis.entries) {
    group('${entry.key}.processRoutesJson', () {
      late List<(String, String)> errors;
      void onError(String route, String error) => errors.add((route, error));
      setUp(() => errors = []);

      test('A: empty detour list, populated regular points', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {'pt': _points(10, stopAt: {5}), 'dtrpt': []},
            ],
          }),
          onError,
        );

        expect(errors, isEmpty);
        expect(routes, hasLength(1));
        expect(routes.single.routeId, 'CN');
        expect(routes.single.points, hasLength(10));
        expect(routes.single.stops, hasLength(1));
        expect(routes.single.stops.single.$1, 5);
        expect(routes.single.stops.single.$2.id, 'S5');
      });

      test('B: populated detour list, empty regular points', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {'pt': [], 'dtrpt': _points(10, stopAt: {5})},
            ],
          }),
          onError,
        );

        expect(errors, isEmpty);
        expect(routes, hasLength(1));
        expect(routes.single.points, isEmpty);
        expect(routes.single.stops, isEmpty);
      });

      test('B: detours are ignored when regular points exist', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {
                'pt': _points(10, stopAt: {5}),
                'dtrpt': _points(7, stopAt: {3}),
              },
            ],
          }),
          onError,
        );

        expect(errors, isEmpty);
        expect(routes, hasLength(1));
        expect(routes.single.points, hasLength(10));
        expect(routes.single.stops.single.$2.id, 'S5');
      });

      test('both lists empty', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {'pt': [], 'dtrpt': []},
            ],
          }),
          onError,
        );

        expect(errors, isEmpty);
        expect(routes.single.points, isEmpty);
        expect(routes.single.stops, isEmpty);
      });

      for (final count in [0, 1, 2, 3]) {
        for (final withDetour in [false, true]) {
          final detourLabel = withDetour ? 'with' : 'without';

          test(
            'C: $count regular points, no stops, $detourLabel detours',
            () async {
              final routes = await entry.value(
                _json({
                  'CN': [
                    {
                      'pt': _points(count),
                      if (withDetour) 'dtrpt': _points(count),
                    },
                  ],
                }),
                onError,
              );

              expect(errors, isEmpty);
              expect(routes, hasLength(1));
              expect(routes.single.points, hasLength(count));
              expect(routes.single.stops, isEmpty);
            },
          );

          test(
            'C: $count regular points ending in a stop, $detourLabel detours',
            () async {
              // Stop rotation needs neighbouring points; with so few points
              // that can fail. The parser must report it, never throw.
              final routes = await entry.value(
                _json({
                  'CN': [
                    {
                      'pt': _points(count, stopAt: {count - 1}),
                      if (withDetour) 'dtrpt': _points(count),
                    },
                  ],
                }),
                onError,
              );

              if (count == 0) {
                expect(errors, isEmpty);
                expect(routes.single.points, isEmpty);
              } else {
                // Subroute is either kept or reported, never silently lost.
                expect(routes.length + errors.length, 1);
              }
            },
          );
        }
      }

      test('a bad subroute is reported without losing the others', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {'pt': _points(10, stopAt: {5})},
              {'pt': _points(2, stopAt: {1})},
              {'pt': _points(10)},
            ],
            'CS': [
              {'pt': _points(6)},
            ],
          }),
          onError,
        );

        expect(errors.length, lessThanOrEqualTo(1));
        expect(routes.length + errors.length, 4);
        expect(routes.map((r) => r.routeId), contains('CS'));
      });

      test('points missing lat/lon fall back to 0 and do not crash', () async {
        final routes = await entry.value(
          _json({
            'CN': [
              {
                'pt': [
                  for (var i = 0; i < 8; i++) <String, dynamic>{'typ': 'W'},
                ],
                'dtrpt': [],
              },
            ],
          }),
          onError,
        );

        expect(routes.length + errors.length, 1);
      });

      test('no routes at all', () async {
        final routes = await entry.value(_json({}), onError);
        expect(routes, isEmpty);
        expect(errors, isEmpty);
      });
    });
  }
}
