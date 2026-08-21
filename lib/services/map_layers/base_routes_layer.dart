import 'dart:math' as math;

import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const double FANCY_ICONS_ZOOM_THRESHOLD = 17.55;
const int STAGGERED_RELOAD_CHUNK_SIZE = 50; // Load this many markers at a time when doing staggered reloads

class StopReloadEntry {
  final BusStop stop;
  final String routeKey;
  final Color routeColor;

  StopReloadEntry({required this.stop, required this.routeKey, required this.routeColor});
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
  @override
  Function(LatLng) showRipple = (LatLng location) {
    debugPrint("Warning! showRipple called but no callback was registered");
  };
  Function(BusStop) onStopClicked = (BusStop s) {
    debugPrint("Warning! onStopClicked called but no callback was registered");
  };

  bool displayFancyIcons = false; // Whether we're zoomed in far enough to show fancy stop icons

  List<BusRouteLine> routesCache = [];
  Map<String, Set<String>> stopIdToRouteIds = {};
  Map<String, BusStop> stopIdToStop = {};

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

  LatLng viewportLocation = LatLng(42.280427, -83.736522); // Default/dummy coordinates we expect to get overwritten as soon as the user pans the map

  // Map<String, Map<String, Marker>> markersCache = {};

  int _markerGeneration = 0; // This increments each time all the markers are regenerated
  Map<String, Marker> markersCache = {}; // New mapping scheme: Stop ID -> Marker. Prevents duplicates
  Map<String, int> _markerBuiltAtGeneration = {}; // This is used to prevent duplicate stop markers while ensuring every marker gets refreshed. This maps (Stop ID) -> (_markerGeneration value when the marker was created). Used to check if a particular marker needs to be refreshed

  Map<String, Polyline> polylinesCache = {};

  void cacheRoutes(List<BusRouteLine> routes) async {
    // Called from inside _loadAllData() inside map_screen.dart
    routesCache = routes;

    for (final r in routesCache) {
      for ((int, BusStop) stopInfo in r.stops) {
        stopInfo.$2;
        // stopIdToRouteId["hello"].add("Hi");
        stopIdToRouteIds.putIfAbsent(stopInfo.$2.id, () => {}).add(r.routeId);

        if (!stopIdToStop.containsKey(stopInfo.$2.id)) {
          stopIdToStop[stopInfo.$2.id] = stopInfo.$2;
        }
      }
    }

    // debugPrint("Pre-generating fancy stop icons");
    for (MapEntry entry in stopIdToRouteIds.entries) {
      try {
        await MapImageService.getFancyStopIcon(
          entry.key,
          favoriteStops.contains(entry.key),
          stopIdToStop[entry.key]?.isRide ?? false,
          stopIdToStop![entry.key]!.rotation,
          entry.value.toList()
        ); // Pre-cache each icon so it's faster later!
      } catch (err) {}
    }

    // TODO: Sort the routeIDs for each key? Do we need to do this or is it already sorted? (It might be already sorted since we're going through the same ordering of routes each time)

    await reloadAllMarkers();
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

  void reload() async {
    await reloadAllMarkers();
    reloadPolylines();
    if (isVisible) onUpdate();
  }

  // TODO: Add caching so this doesn't have to recompute markers for each stop each time

  @override
  void onCameraMove(CameraPosition oldPosition, CameraPosition newPosition) async {
    

    viewportLocation = newPosition.target;

    if (oldPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD) {
      displayFancyIcons = true;
      reloadAllMarkersStaggered();
    } else if (oldPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD) {
      displayFancyIcons = false;
      reloadAllMarkersStaggered();
    }
  }

  double getSquaredDistanceBetween(LatLng a, LatLng b) {
    double lat_delta = a.latitude - b.latitude;
    double lon_delta = a.longitude - b.longitude;
    return lat_delta * lat_delta + lon_delta * lon_delta; // a^2 + b^2: Pythagorean theorem, sans square root (to make the calculation a little faster)
  }

  

  List<StopReloadEntry> stopsToReload = [];
  int stopsToReloadCursor = 0;

  void preprocessStopsToReload(List<BusRouteLine> routes) {
    // Fills the stopsToReload List and sorts them by distance to the viewport
    stopsToReload.clear();
    stopsToReloadCursor = 0;

    for (final r in routes) { // used to be routesCache
      if (!selectedRoutes.contains(r.routeId)) continue; // Skip deselected routes



      // TODO: VVV Save these two variables in some data structure somewhere, or maybe alongside the Stop in the stopsToReload 

      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';

      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      for (final (_, stop) in r.stops) {
        // iterate through all stops in this route

        if (_markerBuiltAtGeneration[stop.id] == _markerGeneration) {
          continue; // This is a duplicate marker that has already been updated. Skip it
        }
        _markerBuiltAtGeneration[stop.id] = _markerGeneration;
        stopsToReload.add(StopReloadEntry(stop: stop, routeKey: routeKey, routeColor: routeColor));

      }
    }

    stopsToReload.sort((a, b) => getSquaredDistanceBetween(a.stop.location, viewportLocation).compareTo(getSquaredDistanceBetween(b.stop.location, viewportLocation))); // Sort by distance to the viewport

  }

  Future<void> reloadPreprocessedMarkersSegment(int markersToReload) async {

    int stopIndex = stopsToReloadCursor + markersToReload;

    for (; stopsToReloadCursor < math.min(stopsToReload.length, stopIndex); stopsToReloadCursor++) {


      // iterate through all stops in this route
      StopReloadEntry entry = stopsToReload[stopsToReloadCursor];

      // List<String> routesServed = ["BB", "CS", "CN", "CSX"];
      Set<String> routesServed = stopIdToRouteIds[entry.stop.id] ?? {};

      final marker = Marker(
        zIndexInt:
            2000, // Put bus stops on top of buses, since all bus Z-indexes are between 0 and 999
        markerId: MarkerId('stop_${entry.stop.id}_${entry.routeKey}'),
        position: entry.stop.location,
        flat: true,
        icon:
            // TODO: Reimplement this isRide/isNotRide/isFavorite/etc logic
            (displayFancyIcons)
              ? (
                await MapImageService.getFancyStopIcon(
                  entry.stop.id,
                  favoriteStops.contains(entry.stop.id),
                  entry.stop.isRide,
                  entry.stop.rotation,
                  routesServed.toList()
                )
              ) : (
                favoriteStops.contains(entry.stop.id) // Used to be isFavorite
                ? (entry.stop.isRide ? _favRideStopIcon : _favStopIcon)
                : (entry.stop.isRide ? _rideStopIcon : _stopIcon)
            ),
        consumeTapEvents: true,
        onTap: () {
          showRipple(entry.stop.location);
          onStopClicked(entry.stop);
        },
        rotation: displayFancyIcons ? 0.0 : entry.stop.rotation,
        anchor: displayFancyIcons ? MapImageService.getFancyStopIconOffset() : Offset(0.5, 0.5),
      );

      markersCache[entry.stop.id] = marker;

    }
    markers = markersCache.values.toSet(); // Update global markers list
  }

    
  Future<void> reloadAllMarkers() async {
    try {
      markersCache.clear();
      _markerGeneration++;

      preprocessStopsToReload(routesCache);
      await reloadPreprocessedMarkersSegment(stopsToReload.length); // Reload ALL the markers at once. This also updates the markers variable

    } catch (err) {
      debugPrint("Error: $err");
    }
  }

  Future<void> reloadAllMarkersStaggered() async {
    // Accomplishes the same function as reloadAllMarkers(), but for big marker changes (i.e. adding fancy stop icons) where reloading everything on one frame causes lots of stuttering. It spreads the work across several frames to reduce jank
    _markerGeneration++;

    int initialMarkerGeneration = _markerGeneration;

    preprocessStopsToReload(routesCache);

    while (stopsToReloadCursor < stopsToReload.length) {

      if (initialMarkerGeneration < _markerGeneration) break; // Race condition prevention--if _markerGeneration is newer, then some future call to reloadAllMarkersStaggered() is already happening and this one should stop

      await reloadPreprocessedMarkersSegment(STAGGERED_RELOAD_CHUNK_SIZE);
      if (isVisible) onUpdate();
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    if (isVisible) onUpdate();

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

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  @override
  void setShowRipple(Function(LatLng) callback) {
    showRipple = callback;
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
