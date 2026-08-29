import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationLayer extends CompositeMapLayer {
  @override
  bool isVisible = true;
  @override
  Set<Polyline> polylines = {};
  @override
  Set<Marker> markers = {};
  @override
  Function() onUpdate = () {};
  Function(BusStop) onStopClicked = (BusStop s) {
    debugPrint("Warning! onStopClicked called but no callback was registered");
  };

  void init(
  ) {
    //...
  }

  void reload() {
    // reloadMarkers();
    // reloadPolylines();
    if (isVisible) onUpdate();
  }

  void setMarkers(Set<Marker> markers_in) {
    this.markers = markers_in;
  }

  void setPolylines(Set<Polyline> polylines_in) {
    this.polylines = polylines_in;
  }

  void reloadMarkers() {
    //...
  }

  void reloadPolylines() {
    //...
  }

  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }
}
