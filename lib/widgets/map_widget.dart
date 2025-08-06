import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Map widget for the map screen
class MapWidget extends StatelessWidget {
  final LatLng initialCenter;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final void Function(GoogleMapController)? onMapCreated;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;

  const MapWidget({
    super.key,
    required this.initialCenter,
    required this.polylines,
    required this.markers,
    this.onMapCreated,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = true,
    this.mapToolbarEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: 15.0,
      ),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      mapToolbarEnabled: mapToolbarEnabled,
      polylines: polylines,
      markers: markers,
    );
  }
} 