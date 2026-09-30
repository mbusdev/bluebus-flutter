import 'dart:math';

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

class SearchResultLayer extends CompositeMapLayer {
  @override
  bool isVisible = true;

  @override
  Set<Marker> markers = {};
  LatLng position = LatLng(0,0);

  @override
  Function() onUpdate = () {
    debugPrint("Error: onUpdate called but callback was not registered!");
  };

  @override
  Set<Polyline> polylines = {};

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  void reload() {
    onUpdate();
  }

  void updateMarkers() {
    markers.clear();
    markers.add(Marker(
      flat: true,
      markerId: MarkerId('search_result'),
      icon: BitmapDescriptor.defaultMarker,
      position: position,
    ));
  }

  void setPosition(LatLng position_in) {
    position = position_in;
    updateMarkers();
    onUpdate();
  }

}
// NEXT STEPS TODO: Finish getting the BusSheet to be a non-modal sheet, and auto-follow the bus as it moves! Also save the location from before the BusSheet was opened so it can be navigated back to?
