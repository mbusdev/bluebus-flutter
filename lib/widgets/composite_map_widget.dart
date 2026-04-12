import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

// Create a bus marker from a Bus model
// Marker _createBusMarker(Bus bus) {
//   final routeColor =
//       bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);
//   final icon =
//       _routeBusIcons[bus.routeId] ??
//       _busIcon ??
//       BitmapDescriptor.defaultMarkerWithHue(_colorToHue(routeColor));
//   return Marker(
//     flat: true,
//     markerId: MarkerId('bus_${bus.id}'),
//     consumeTapEvents: true,
//     position: bus.position,
//     icon: icon,
//     rotation: bus.heading,
//     anchor: const Offset(0.5, 0.5),
//     onTap: () => _showBusSheet(bus.id),
//   );
// }



// TODO: Add a Z-index to each thing in each CompositeMapLayer
//    to explicitly define how things should be ordered

// Define the CompositeMapLayer
abstract class CompositeMapLayer {
  // Every CompositeMapLayer must have these four things
  bool get isVisible;
  Set<Polyline> get polylines;
  Set<Marker> get markers;
  Function() get onUpdate;
  void setOnUpdate(Function() fn);
}

class BaseRoutesLayer extends CompositeMapLayer {
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

  List<BusRouteLine> routesCache = [];

  Set<String> favoriteStops = {};
  Set<String> selectedRoutes = {};

  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _rideStopIcon;
  BitmapDescriptor? _favStopIcon;
  BitmapDescriptor? _favRideStopIcon;

  Map<String, Map<String, Marker>> markersCache = {}; // TODO: Merge this with polylines variable?
  Map<String, Polyline> polylinesCache = {};

  void setOnUpdate(Function() callback) {
    debugPrint("****** got setOnUpdate call!");
    onUpdate = callback;
  }

  void init(Set<String> favoriteStops_in,
    Set<String> selectedRoutes_in,
    Function(BusStop) onStopClicked_in) {
    favoriteStops = favoriteStops_in;
    selectedRoutes = selectedRoutes_in;
    onStopClicked = onStopClicked_in;
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      // Load stop icons
      _stopIcon = await MapImageService.resizeImage(
        await rootBundle.load('assets/busStop.png'),
      );
      _rideStopIcon = await MapImageService.resizeImage(
        await rootBundle.load('assets/busStopRide.png'),
      );
      _favStopIcon = await MapImageService.resizeImage(
        await rootBundle.load('assets/favbusStop.png'),
      );
      _favRideStopIcon = await MapImageService.resizeImage(
        await rootBundle.load('assets/favbusStopRide.png'),
      );

      // Refresh markers with new icons
      // TODO: See if we need this!
      // if (mounted) {
      //   _refreshAllMarkers();
      // }
    } catch (e) {
      // Fallback to default markers if custom loading fails
      _stopIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
      _rideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
      _favStopIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
      _favRideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
  }

  void reload() {
    debugPrint("****** Reloading everything in busRoutesLayer");
    reloadMarkers();
    reloadPolylines();
    onUpdate();
  }

  void reloadMarkers() {
    // set force to reload all the markers, regardless of whether they're already in the cache or not. Useful if a marker changes state (e.g. becomes a favorite) but is already in the cache

    debugPrint("***** Got reloadMarkers call");

    markersCache.clear();

    for (final r in routesCache) {
      if (!selectedRoutes.contains(r.routeId)) continue; // Skip deselected routes
      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      if (!markersCache.containsKey(routeKey)) {
        markersCache[routeKey] = {};
        for (final stop in r.stops) { // iterate through all stops in this route
          // TODO: Implement favorite stops
          // final isFavorite = _favoriteStops.contains(stop.id);
          
          final marker = Marker(
            markerId: MarkerId(
              'stop_${stop.id}_${Object.hashAll(r.points)}',
            ),
            position: stop.location,
            flat: true,
            // icon: BitmapDescriptor.defaultMarker,
            icon: favoriteStops.contains(stop.id) // Used to be isFavorite
                ? (stop.isRide
                      ? _favRideStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )
                      : _favStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ))
                : (stop.isRide
                      ? _rideStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )
                      : _stopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )),
            consumeTapEvents: true,
            onTap: () {
              onStopClicked(stop);
            },
            rotation: stop.rotation,
            anchor: Offset(0.5, 0.5),
          );
          // _routeStopMarkers[routeKey]?[stop.id] = marker;

          markersCache[routeKey]?[stop.id] = marker;

          // gets first marker of this stop and adds it to the favorited stop markers 
          // if (isFavorite && !_displayedFavoriteStopMarkers.containsKey(stop.id)) {
          //   _displayedFavoriteStopMarkers[stop.id] = marker;
          // }
          // _stopIsRide[stop.id] = stop.isRide;
        }
      }
    }

    // markers = {};
    markers = markersCache.values.expand((Map<String, Marker> m) {
      return m.values;
    }).toSet();
  }

  void reloadPolylines() {

    for (final r in routesCache) {
      if (!selectedRoutes.contains(r.routeId)) continue; // Skip deselected routes

      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      //   TODO: Implement this
      if (!polylinesCache.containsKey(routeKey)) {
        polylinesCache[routeKey] = Polyline(
          polylineId: PolylineId(routeKey),
          points: r.points,
          color: routeColor,
          width: 4,
        );
      }
    }

    polylines = polylinesCache.values.toSet();

  }

  void cacheRoutes(List<BusRouteLine> routes) {
    debugPrint("******* Got cacheRoutes call!!");
    // Called from inside _loadAllData() inside map_screen.dart
    routesCache = routes;

    // TODO: Make the parent (map_screen.dart) pass in the list of filtered route IDs and as soon as that list changes call some sort of reloadMarkers()

    // TODO: Update the map controller here
    debugPrint("Calling onUpdate: ${onUpdate}");

    reloadMarkers();
    reloadPolylines();

    onUpdate();
  }

  
}

class LiveBusesLayer extends CompositeMapLayer {
  @override
  bool isVisible = true;

  @override
  Set<Marker> markers = {};

  @override
  Function() onUpdate = () {
    debugPrint("Error: onUpdate called but callback was not registered!");
  };

  @override
  Set<Polyline> polylines = {};

  List<Bus> buses = [];
  Set<String> selectedRoutes = {};
  Function(Bus b) onBusClicked = (Bus b) {
    debugPrint("Error: onBusClicked callback was called but never intiialized");
  };

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  void init(List<Bus> buses_in,
    Set<String> selectedRoutes_in,
    Function(Bus b) onBusClicked_in) {
    buses = buses_in;
    selectedRoutes = selectedRoutes_in;
    onBusClicked = onBusClicked_in;
    MapImageService.loadData();
  }

  Marker createBusMarker(Bus bus) {
    final icon = MapImageService.getBusIcon(bus);
    return Marker(
      flat: true,
      markerId: MarkerId('bus_${bus.id}'),
      consumeTapEvents: true,
      position: bus.position,
      icon: icon,
      rotation: bus.heading,
      anchor: const Offset(0.5, 0.5),
      onTap: () => onBusClicked(bus),
    );
  }

  void reload() { // Similar to how _updateDisplayedBuses() worked before
// null case or error contacting server case
    if (buses == []) return;

    markers = buses
      .where((bus) => selectedRoutes.contains(bus.routeId))
      .map((bus) {
        // Use route specific bus icon if available, otherwise fallback to default
        BitmapDescriptor? busIcon = MapImageService.getBusIcon(bus);

        NEXT STEPS TODO: Get bus animations working on android, and get the live updating to work!

        return Marker(
          flat: true,
          markerId: MarkerId('bus_${bus.id}'),
          consumeTapEvents: true,
          position: bus.position,
          icon: busIcon,
          rotation: bus.heading,
          anchor: const Offset(0.5, 0.5), // Center the icon on the position
          onTap: () {
            try {
              Haptics.vibrate(HapticsType.light);
            } catch (e) {}
            onBusClicked(bus);
            // _showBusSheet(bus.id);
          },
        );
      })
      .toSet();
  }

}


class CompositeMapWidget extends StatefulWidget {
  // final LatLongNew.LatLng initialCenter = LatLongNew.LatLng(42.277849, -83.7352536);
  // final Set<Polyline> polylines;
  // final Set<Marker> markers;
  // final void Function(GoogleMapController)? onMapCreated;
  // final void Function(CameraPosition)? onCameraMove;
  // final bool myLocationEnabled;
  // final bool myLocationButtonEnabled;
  // final bool zoomControlsEnabled;
  // final bool mapToolbarEnabled;
  // Function(BusStop stop) onStopClicked;
  // Function(Bus bus) onBusClicked;

  final LatLng initialCenter;
  final List<CompositeMapLayer> mapLayers;

// TODO: Implement these methods
  // void _onMapCreated(GoogleMapController controller) {
  //   _mapController = controller;
  // }

  // void _onCameraMove(CameraPosition position) async {
  //   _currentCameraPos = position;
  // }

  // void _onCameraIdle() async {
  //   // check if user location is within viewport bounds
  //   LatLngBounds? viewportBounds = await _mapController?.getVisibleRegion();
  //   if (viewportBounds != null) {
  //     Position? pos = await _getLastKnownLocation();
  //     if (pos != null) {
  //       _userLocVisible = !viewportBounds.contains(
  //         LatLng(pos.latitude, pos.longitude),
  //       );
  //     }
  //   }
  // }
  
  
  // final UniversalMapController universalController;
  
  CompositeMapWidget({
    required this.initialCenter,
    required this.mapLayers
  });
  
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return CompositeMapWidgetState();
  }

  
}


class CompositeMapWidgetState extends State<CompositeMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> allMarkers = {};
  Set<Polyline> allPolylines = {};


  void reloadMap() {
    debugPrint("******* Got reloadMap() call!");
    // _mapController.
    setState(() {}); // Rebuild with updated markers
  }

  @override
  initState() {
    super.initState();
    widget.mapLayers.forEach((CompositeMapLayer layer) {
      layer.setOnUpdate(reloadMap);
    });

  }

  @override
  Widget build(BuildContext context) {
    // widget.mapLayers.forEach((CompositeMapLayer layer) {
    //   if (!layer.isVisible) return;
    //   allallMarkers.union(other)
    // });
  allMarkers = widget.mapLayers.expand<Marker>((CompositeMapLayer layer) {
    if (!layer.isVisible) return {};
    return layer.markers;
  }).toSet(); //Flatten all the markers from each layer into one big layer
  allPolylines = widget.mapLayers.expand<Polyline>((CompositeMapLayer layer) {
    if (!layer.isVisible) return {};
    return layer.polylines;
  }).toSet();

  // allmarkers = 

  debugPrint("******* Got CompositeMapWidget build command! #markers is ${allMarkers.length}");
  


    return RepaintBoundary(
      child: GoogleMap(
        compassEnabled: false,
        myLocationEnabled: true,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        markers: allMarkers,
        polylines: allPolylines,
        // controller: 
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            southwest: LatLng(42.217530, -83.84367266), // Southern and Westernmost point
            northeast: LatLng(42.328602, -83.53892646), // Northern and Easternmost point 
          )
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(10, 21),
        // markers: curMarkers.union(widget.staticMarkers),
        initialCameraPosition: CameraPosition(
          target: widget.initialCenter,
          zoom: 15.0,
        ),
        onMapCreated:(controller) {
          _mapController = controller;
        },
      )
    );
  }


}