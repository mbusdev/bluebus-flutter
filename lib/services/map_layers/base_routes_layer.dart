import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  BitmapDescriptor _stopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  BitmapDescriptor _rideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  BitmapDescriptor _favStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  BitmapDescriptor _favRideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );

  Map<String, Map<String, Marker>> markersCache =
      {}; // TODO: Merge this with polylines variable?
  Map<String, Polyline> polylinesCache = {};

  void cacheRoutes(List<BusRouteLine> routes) {
    // Called from inside _loadAllData() inside map_screen.dart
    routesCache = routes;

    reloadMarkers();
    reloadPolylines();

    if (isVisible) onUpdate();
  }

  void init(
    Set<String> favoriteStops_in,
    Set<String> selectedRoutes_in,
    Function(BusStop) onStopClicked_in,
  ) {
    favoriteStops = favoriteStops_in;
    selectedRoutes = selectedRoutes_in;
    onStopClicked = onStopClicked_in;
    _loadCustomMarkers();
  }

  void reload() {
    reloadMarkers();
    reloadPolylines();
    if (isVisible) onUpdate();
  }

  void reloadMarkers() {
    markersCache.clear();

    for (final r in routesCache) {
      if (!selectedRoutes.contains(r.routeId))
        continue; // Skip deselected routes
      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      if (!markersCache.containsKey(routeKey)) {
        // Prevent duplicate copies of the same stop on top of each other
        markersCache[routeKey] = {};
        for (final stop in r.stops) {
          // iterate through all stops in this route
          // TODO: Implement favorite stops
          // final isFavorite = _favoriteStops.contains(stop.id);

          final marker = Marker(
            zIndexInt:
                2000, // Put bus stops on top of buses, since all bus Z-indexes are between 0 and 999
            markerId: MarkerId('stop_${stop.id}_${Object.hashAll(r.points)}'),
            position: stop.location,
            flat: true,
            // icon: BitmapDescriptor.defaultMarker,
            icon:
                favoriteStops.contains(stop.id) // Used to be isFavorite
                ? (stop.isRide ? _favRideStopIcon : _favStopIcon)
                : (stop.isRide ? _rideStopIcon : _stopIcon),
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
    polylinesCache.clear();

    for (final r in routesCache) {
      if (!selectedRoutes.contains(r.routeId))
        continue; // Skip deselected routes

      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      if (!polylinesCache.containsKey(routeKey)) {
        polylinesCache[routeKey] = Polyline(
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          polylineId: PolylineId(routeKey),
          points: r.points,
          color: routeColor,
          width: 4,
        );
      }
    }

    polylines = polylinesCache.values.toSet();
  }

  void setOnUpdate(Function() callback) {
    onUpdate = callback;
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
      // These are now set as initial values
      // _stopIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueAzure,
      // );
      // _rideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueAzure,
      // );
      // _favStopIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueAzure,
      // );
      // _favRideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueAzure,
      // );
    }
  }
}
