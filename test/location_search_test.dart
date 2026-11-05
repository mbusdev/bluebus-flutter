import 'package:bluebus/constants.dart';
import 'package:bluebus/services/location_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Location _building(String name, double lat, double lng) =>
    Location(name, '', const [], false, latlng: LatLng(lat, lng));

void main() {
  // Same text match for the query "hall", different places on campus.
  final north = _building('North Hall', 42.26, -83.74); // eecs
  final central = _building('Central Hall', 42.276888, -83.73816); // diag
  final south = _building('South Hall', 42.269155, -83.742728); // im
  final index = buildNgramIndex([north, central, south]);

  const nearNorth = LatLng(42.2935, -83.7165);
  const nearSouth = LatLng(42.2595, -83.7405);

  test('closest equally-good text match comes first (north)', () {
    final results = searchLocations('hall', index, const [], center: nearNorth);
    expect(results.first.name, 'North Hall');
    expect(results.last.name, 'South Hall');
  });

  test('moving the center changes the order (south)', () {
    final results = searchLocations('hall', index, const [], center: nearSouth);
    expect(results.first.name, 'South Hall');
    expect(results.last.name, 'North Hall');
  });

  test('without a center it still returns every match', () {
    final results = searchLocations('hall', index, const []);
    expect(results.map((l) => l.name).toSet(),
        {'North Hall', 'Central Hall', 'South Hall'});
  });

  test('locations with no coordinates sort last', () {
    final noCoords = Location('Mystery Hall', '', const [], false);
    final idx = buildNgramIndex([noCoords, south, north]);
    final results = searchLocations('hall', idx, const [], center: nearNorth);
    expect(results.last.name, 'Mystery Hall');
  });
}
