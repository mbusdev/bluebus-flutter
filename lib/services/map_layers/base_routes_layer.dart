import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const double FANCY_ICONS_ZOOM_THRESHOLD = 17.55;

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

  Map<String, Map<String, Marker>> markersCache =
      {}; // TODO: Merge this with polylines variable?
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

    debugPrint("Pre-generating fancy stop icons");
    for (MapEntry entry in stopIdToRouteIds.entries) {
      try {
        MapImageService.getFancyStopIcon(entry.key, stopIdToStop![entry.key]!.rotation, entry.value.toList()); // Pre-cache each icon so it's faster later!
      } catch (err) {}
    }

    // TODO: Sort the routeIDs for each key? Do we need to do this or is it already sorted? (It might be already sorted since we're going through the same ordering of routes each time)

    // stopIdToRouteId.entries.forEach((e) => {
    //   debugPrint("Bus stop ${e.key} has service from ${e.value.join(", ")}")
    // },);

    await reloadMarkers();
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
    await reloadMarkers();
    reloadPolylines();
    if (isVisible) onUpdate();
  }

  // TODO: Add caching so this doesn't have to recompute markers for each stop each time

  @override
  void onCameraMove(CameraPosition oldPosition, CameraPosition newPosition) async {
    // debugPrint("Camera zoomed from ${oldPosition.zoom} to ${newPosition.zoom}");
    if (oldPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD) {
      debugPrint("******* ENABLING FANCY ICONS");
      displayFancyIcons = true;
      await reloadMarkers();
      if (isVisible) onUpdate();
    } else if (oldPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD) {
      debugPrint("******* DISABLING FANCY ICONS");
      displayFancyIcons = false;
      await reloadMarkers();
      if (isVisible) onUpdate();
    }
  }

  Future<void> reloadMarkers() async {
    try {
      markersCache.clear();

      // FUTURE TODO: Create these icons asynchronously and CACHE THEM so they don't block when we're trying to load them all. Make sure they display all available routes even if only a few are selected (so the cache doesn't become invalid when the user selects different routes)


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
          for (final (idx, stop) in r.stops) {
            // iterate through all stops in this route
            // TODO: Implement favorite stops
            // final isFavorite = _favoriteStops.contains(stop.id);


            // TODO: ****** See why the duplicate cache isn't working in some cases!

            // List<String> routesServed = ["BB", "CS", "CN", "CSX"];
            Set<String> routesServed = stopIdToRouteIds[stop.id] ?? {};

            final marker = Marker(
              zIndexInt:
                  2000, // Put bus stops on top of buses, since all bus Z-indexes are between 0 and 999
              markerId: MarkerId('stop_${stop.id}_${Object.hashAll(r.points)}'),
              position: stop.location,
              flat: true,
              // icon: BitmapDescriptor.defaultMarker,
              icon:
                  // TODO: Reimplement this isRide/isNotRide/isFavorite/etc logic
                  // favoriteStops.contains(stop.id) // Used to be isFavorite
                  // ? (stop.isRide ? MapImageService.favRideStopIcon : MapImageService.favStopIcon)
                  // : (stop.isRide ? MapImageService.rideStopIcon : MapImageService. stopIcon),
                  (displayFancyIcons) ? await MapImageService.getFancyStopIcon(stop.id, stop.rotation, routesServed.toList()) : MapImageService.stopIcon,

                  // NEXT STEPS TODO:
                  // * Stagger the marker updates across frames, instead of trying to load them in all at once. Process maybe 50-100 markers at a time before waiting
                  // * Add support for favorited stops (add the favorite/nonfavorite flag as part of the cache key to make sure our cache won't give us an old icon)
                  // * 

                  // TODO: Maybe only generate fancy stop icons if we can confirm the Marker is within view?


                  // favoriteStops.contains(stop.id) // Used to be isFavorite
                  // ? (stop.isRide ? _favRideStopIcon : _favStopIcon)
                  // : (stop.isRide ? _rideStopIcon : _stopIcon),
              consumeTapEvents: true,
              onTap: () {
                onStopClicked(stop);
              },
              rotation: displayFancyIcons ? 0.0 : stop.rotation,
              anchor: displayFancyIcons ? MapImageService.getFancyStopIconOffset() : Offset(0.5, 0.5),
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
    } catch (err) {
      debugPrint("Error: $err");
    }
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
