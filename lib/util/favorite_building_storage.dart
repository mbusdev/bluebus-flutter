import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants.dart';

const String kFavoriteBuildingsPrefsKey = 'favorite_buildings';

String favoriteBuildingStorageId(Location b) {
  final ll = b.latlng;
  if (ll != null) {
    return 'geo:${ll.latitude.toStringAsFixed(6)},${ll.longitude.toStringAsFixed(6)}';
  }
  return 'name:${b.name}';
}

String encodeFavoriteBuilding(Location b) {
  final ll = b.latlng;
  return jsonEncode({
    'id': favoriteBuildingStorageId(b),
    'name': b.name,
    'abbrev': b.abbrev,
    if (ll != null) 'lat': ll.latitude,
    if (ll != null) 'lon': ll.longitude,
  });
}

/// Stable id for a row in [kFavoriteBuildingsPrefsKey], whether JSON or legacy plain id.
String? favoriteBuildingEntryId(String stored) {
  try {
    final m = jsonDecode(stored) as Map<String, dynamic>;
    return m['id'] as String?;
  } catch (_) {
    if (stored.startsWith('geo:') || stored.startsWith('name:')) {
      return stored;
    }
    return null;
  }
}

class FavoriteBuildingEntry {
  final String raw;
  final String id;
  final String name;
  final String abbrev;
  final double? lat;
  final double? lon;

  const FavoriteBuildingEntry({
    required this.raw,
    required this.id,
    required this.name,
    required this.abbrev,
    required this.lat,
    required this.lon,
  });

  Location? toLocation() {
    if (lat == null || lon == null) return null;
    return Location(
      name,
      abbrev,
      const [],
      false,
      latlng: LatLng(lat!, lon!),
    );
  }
}

FavoriteBuildingEntry? decodeFavoriteBuildingEntry(String stored) {
  try {
    final m = jsonDecode(stored) as Map<String, dynamic>;
    final id = m['id'] as String?;
    if (id == null) return null;
    return FavoriteBuildingEntry(
      raw: stored,
      id: id,
      name: m['name'] as String? ?? 'Building',
      abbrev: m['abbrev'] as String? ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lon: (m['lon'] as num?)?.toDouble(),
    );
  } catch (_) {
    return _decodeLegacyFavoriteBuildingEntry(stored);
  }
}

FavoriteBuildingEntry? _decodeLegacyFavoriteBuildingEntry(String stored) {
  if (!stored.startsWith('geo:')) return null;
  final rest = stored.substring(4);
  final comma = rest.indexOf(',');
  if (comma <= 0 || comma >= rest.length - 1) return null;
  final lat = double.tryParse(rest.substring(0, comma));
  final lon = double.tryParse(rest.substring(comma + 1));
  if (lat == null || lon == null) return null;
  return FavoriteBuildingEntry(
    raw: stored,
    id: stored,
    name: 'Saved building',
    abbrev: '',
    lat: lat,
    lon: lon,
  );
}
