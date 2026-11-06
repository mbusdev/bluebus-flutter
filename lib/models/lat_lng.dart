
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bluebus/backend/export.dart' as backend;

LatLng latLngFromBackend(backend.LatLon ll) {
  return LatLng(ll.lat.toDouble(), ll.lon.toDouble());
}

