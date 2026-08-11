import 'package:bluebus/constants.dart';
import 'package:bluebus/services/map_layers/journey_layer.dart';
import 'package:bluebus/services/map_layers/live_buses_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Define the CompositeMapLayer
abstract class CompositeMapLayer {
  // Every CompositeMapLayer must have these five things
  bool get isVisible;
  Set<Polyline> get polylines;
  Set<Marker> get markers;
  Function() get onUpdate;
  void setOnUpdate(Function() fn);
  void dispose() {}

  // Optional: If they need, CompositeMapLayers can include these things
  void onCameraMove(CameraPosition oldPosition, CameraPosition newPosition) {}
}

// TODO: Extend the MapController back to map_screen.dart so it can move the camera and stuff

class CompositeMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final List<CompositeMapLayer> mapLayers;
  final Function(GoogleMapController) onMapCreated;
  final ValueChanged<CameraPosition>? onCameraMove;
  final VoidCallback? onCameraIdle;

  CompositeMapWidget({
    required this.initialCenter,
    required this.mapLayers,
    required this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
  });

  @override
  State<StatefulWidget> createState() {
    return CompositeMapWidgetState();
  }
}

class CompositeMapWidgetState extends State<CompositeMapWidget>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> allMarkers = {};
  Set<Polyline> allPolylines = {};
  CameraPosition? oldCameraPosition;

  void reloadMap() {
    setState(() {}); // Rebuild with updated markers
  }

  // GoogleMaps styles
  String _darkMapStyle = "{}";
  String _lightMapStyle = "{}";

  Future _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/maps_dark_style.json');
    _lightMapStyle = await rootBundle.loadString(
      'assets/maps_light_style.json',
    );
    setState(() {});
  }

  @override
  initState() {
    super.initState();
    _loadMapStyles();
    widget.mapLayers.forEach((CompositeMapLayer layer) {
      layer.setOnUpdate(reloadMap);
      if (layer is LiveBusesLayer) {
        layer.initWithTickerProvider(this);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    allMarkers = widget.mapLayers.expand<Marker>((CompositeMapLayer layer) {
      if (!layer.isVisible) return {};
      return layer.markers;
    }).toSet(); //Flatten all the markers from each layer into one big layer
    allPolylines = widget.mapLayers.expand<Polyline>((CompositeMapLayer layer) {
      if (!layer.isVisible) return {};
      return layer.polylines;
    }).toSet();

    return RepaintBoundary(
      child: GoogleMap(
        compassEnabled: false,
        myLocationEnabled: true,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        markers: allMarkers,
        polylines: allPolylines,
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            southwest: LatLng(
              42.217530,
              -83.84367266,
            ), // Southern and Westernmost point
            northeast: LatLng(
              42.328602,
              -83.53892646,
            ), // Northern and Easternmost point
          ),
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(10, 21),
        // markers: curMarkers.union(widget.staticMarkers),
        initialCameraPosition: CameraPosition(
          target: widget.initialCenter,
          zoom: 15.0,
        ),
        style: isDarkMode(context) ? _darkMapStyle : _lightMapStyle,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          widget.mapLayers.forEach((CompositeMapLayer layer) {
            if (layer is JourneyLayer) {
              layer.setMapController(controller);
            }
          });
          widget.onMapCreated(controller);
        },
        onCameraMove: (CameraPosition position) {

          if (oldCameraPosition == null) {
            // First camera update
            oldCameraPosition = position;

          } else if (oldCameraPosition?.target != position.target ||
                     oldCameraPosition?.tilt != position.tilt ||
                     oldCameraPosition?.zoom != position.zoom) {
            for (CompositeMapLayer layer in widget.mapLayers) {
              layer.onCameraMove(oldCameraPosition!, position);
            }
            oldCameraPosition = position;
          }

          widget.onCameraMove?.call(position);
        },
        onCameraIdle: widget.onCameraIdle,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    //   widget.mapLayers.forEach((CompositeMapLayer l) {
    //     l.dispose();
    // });
    for (CompositeMapLayer l in widget.mapLayers) {
      l.dispose();
    }
  }
}

// REFACTOR TO-DOS

// [Done]: Modify each widget's onUpdate call so it only does anything if the widget is visible
// TODO: Talk to Backend team about getting the polyline data sent alongside the navigation request
// [Done]: Pass the MapController back to map_screen.dart to get features like moving the camera working
// [Done, I think]: Figure out why the bus markers aren't loading sometimes
// TODO: Go back to the normal map view when you swipe away the navigation screen
//    Looks like pressing the Android back button after swiping away the nav screen works--does it still think the sheet is displayed?
// TODO: Talk with team to make nicer "Get on bus" and "Get off bus" icons in navigation
// POSSIBLE: Maybe work on getting Project Smoothbus to snap to routes if it's close? Engineering that will be pretty involved
//    When a new position is received, it'll have to calculate the closest starting point on the line. To do that:
//        1. Find the closest polyline vertex to the bus
//        2. There'll be two possible line segments that include that vertex--Try projecting the bus onto both and pick which is closer
//    Do that same process to calculate the bus's ending point on the line
//    Then:
//        1. Calculate the total distance *along the line* the bus travels through
//        2. Divide this distance into ~100 segments (10 per second) and save them in an array somewhere
//        3. At each frame, move the bus to the next segment
//    NOTE: Some routes "double back" on the same path, which will probably cause problems. We really need a way to distinguish which direction the polyline goes
// POSSIBLE: Make bus stop markers small if you're zoomed out far enough
// POSSIBLE OPTIMIZATION: Only run animation updates for buses that are visible in the viewport?
