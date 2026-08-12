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

    debugPrint("Pre-generating fancy stop icons");
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

    // stopIdToRouteId.entries.forEach((e) => {
    //   debugPrint("Bus stop ${e.key} has service from ${e.value.join(", ")}")
    // },);

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
    // debugPrint("Camera zoomed from ${oldPosition.zoom} to ${newPosition.zoom}");
    if (oldPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD) {
      debugPrint("******* ENABLING FANCY ICONS");
      displayFancyIcons = true;
      // TODO: Add a _markerGeneration++ statement here
      // await reloadAllMarkers();
      // if (isVisible) onUpdate();
      reloadAllMarkersStaggered();
    } else if (oldPosition.zoom >= FANCY_ICONS_ZOOM_THRESHOLD && newPosition.zoom < FANCY_ICONS_ZOOM_THRESHOLD) {
      debugPrint("******* DISABLING FANCY ICONS");
      displayFancyIcons = false;
      reloadAllMarkersStaggered();
      // await reloadAllMarkers();
      // if (isVisible) onUpdate();
    }
  }

  Future<void> reloadMarkersForRoutes(List<BusRouteLine> routes) async {
    // Used to only reload markers for a given list of routes. Useful because the fancy icons take some time for Google Maps to process (replacing 100+ markers with custom icons all at once causes a lot of stuttering), so we only process 1-2 routes per frame to keep things smoother
    for (final r in routes) { // used to be routesCache
      if (!selectedRoutes.contains(r.routeId)) continue; // Skip deselected routes

      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';

      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      // if (!markersCache.containsKey(routeKey)) {
      //   // Prevent duplicate copies of the same stop on top of each other
      //   markersCache[routeKey] = {};
      for (final (idx, stop) in r.stops) {
        // iterate through all stops in this route
        // TODO: Implement favorite stops
        // final isFavorite = _favoriteStops.contains(stop.id);

        if (_markerBuiltAtGeneration[stop.id] == _markerGeneration) {
          continue; // This is a duplicate marker that has already been updated. Skip it
        }
        _markerBuiltAtGeneration[stop.id] = _markerGeneration;


        // List<String> routesServed = ["BB", "CS", "CN", "CSX"];
        Set<String> routesServed = stopIdToRouteIds[stop.id] ?? {};

        final marker = Marker(
          zIndexInt:
              2000, // Put bus stops on top of buses, since all bus Z-indexes are between 0 and 999
          markerId: MarkerId('stop_${stop.id}_${Object.hashAll(r.points)}'),
          position: stop.location,
          flat: true,
          icon:
              // TODO: Reimplement this isRide/isNotRide/isFavorite/etc logic
              (displayFancyIcons)
                ? (
                  await MapImageService.getFancyStopIcon(
                    stop.id,
                    favoriteStops.contains(stop.id),
                    stop.isRide,
                    stop.rotation,
                    routesServed.toList()
                  )
                ) : (
                  favoriteStops.contains(stop.id) // Used to be isFavorite
                  ? (stop.isRide ? _favRideStopIcon : _favStopIcon)
                  : (stop.isRide ? _rideStopIcon : _stopIcon)
              ),
          consumeTapEvents: true,
          onTap: () {
            onStopClicked(stop);
          },
          rotation: displayFancyIcons ? 0.0 : stop.rotation,
          anchor: displayFancyIcons ? MapImageService.getFancyStopIconOffset() : Offset(0.5, 0.5),
        );

        markersCache[stop.id] = marker;

        // gets first marker of this stop and adds it to the favorited stop markers
        // if (isFavorite && !_displayedFavoriteStopMarkers.containsKey(stop.id)) {
        //   _displayedFavoriteStopMarkers[stop.id] = marker;
        // }
        // _stopIsRide[stop.id] = stop.isRide;
      }
    }

    markers = markersCache.values.toSet(); // Update global markers list

  }

  Future<void> reloadAllMarkers() async {
    try {
      markersCache.clear();
      _markerGeneration++;

      // FUTURE TODO: Create these icons asynchronously and CACHE THEM so they don't block when we're trying to load them all. Make sure they display all available routes even if only a few are selected (so the cache doesn't become invalid when the user selects different routes)

      await reloadMarkersForRoutes(routesCache); // Reload all the markers all at once

      // for (final r in routesCache) {
      //   if (!selectedRoutes.contains(r.routeId))
      //     continue; // Skip deselected routes
      //   // Create unique key for each route variant (content-based hash)
      //   final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
      //   // Use backend color if available, otherwise fallback to service
      //   final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      //   if (!markersCache.containsKey(routeKey)) {
      //     // Prevent duplicate copies of the same stop on top of each other
      //     markersCache[routeKey] = {};
      //     for (final (idx, stop) in r.stops) {
      //       // iterate through all stops in this route
      //       // TODO: Implement favorite stops
      //       // final isFavorite = _favoriteStops.contains(stop.id);


      //       // TODO: ****** See why the duplicate cache isn't working in some cases!

      //       // List<String> routesServed = ["BB", "CS", "CN", "CSX"];
      //       Set<String> routesServed = stopIdToRouteIds[stop.id] ?? {};

      //       final marker = Marker(
      //         zIndexInt:
      //             2000, // Put bus stops on top of buses, since all bus Z-indexes are between 0 and 999
      //         markerId: MarkerId('stop_${stop.id}_${Object.hashAll(r.points)}'),
      //         position: stop.location,
      //         flat: true,
      //         // icon: BitmapDescriptor.defaultMarker,
      //         icon:
      //             // TODO: Reimplement this isRide/isNotRide/isFavorite/etc logic
      //             // favoriteStops.contains(stop.id) // Used to be isFavorite
      //             // ? (stop.isRide ? MapImageService.favRideStopIcon : MapImageService.favStopIcon)
      //             // : (stop.isRide ? MapImageService.rideStopIcon : MapImageService. stopIcon),
      //             (displayFancyIcons) ? await MapImageService.getFancyStopIcon(stop.id, stop.rotation, routesServed.toList()) : MapImageService.stopIcon,

      //             // NEXT STEPS TODO:
      //             // * Stagger the marker updates across frames, instead of trying to load them in all at once. Process maybe 50-100 markers at a time before waiting
      //             // * Add support for favorited stops (add the favorite/nonfavorite flag as part of the cache key to make sure our cache won't give us an old icon by mistake')
      //             // * See if I can fix the rotation bug? Some stops have strange rotation--see if there is an existing function to "smooth out" the rotation so that it follows the polyline
      //             // * Make the TheRide stop numbers ovals instead of circles
      //             // * Also sort the list of stops every time!
      //             // * And figure out why I'm getting so many ErrorSummary errors
      //             // We can also think about "snapping"/"binning" the rotation to e.g. 20-degree increments to make the cache a little smaller

      //             // TODO: Maybe only generate fancy stop icons if we can confirm the Marker is within view?


      //             // favoriteStops.contains(stop.id) // Used to be isFavorite
      //             // ? (stop.isRide ? _favRideStopIcon : _favStopIcon)
      //             // : (stop.isRide ? _rideStopIcon : _stopIcon),
      //         consumeTapEvents: true,
      //         onTap: () {
      //           onStopClicked(stop);
      //         },
      //         rotation: displayFancyIcons ? 0.0 : stop.rotation,
      //         anchor: displayFancyIcons ? MapImageService.getFancyStopIconOffset() : Offset(0.5, 0.5),
      //       );
      //       // _routeStopMarkers[routeKey]?[stop.id] = marker;

      //       markersCache[routeKey]?[stop.id] = marker;

      //       // gets first marker of this stop and adds it to the favorited stop markers
      //       // if (isFavorite && !_displayedFavoriteStopMarkers.containsKey(stop.id)) {
      //       //   _displayedFavoriteStopMarkers[stop.id] = marker;
      //       // }
      //       // _stopIsRide[stop.id] = stop.isRide;
      //     }
      //   }
      // }

      // markers = {};
      // markers = markersCache.values.expand((Map<String, Marker> m) {
      //   return m.values;
      // }).toSet();
    } catch (err) {
      debugPrint("Error: $err");
    }
  }

  Future<void> reloadAllMarkersStaggered() async {
    // Accomplishes the same function as reloadAllMarkers(), but for big marker changes (i.e. adding fancy stop icons) where reloading everything on one frame causes lots of stuttering. It spreads the work across several frames to reduce jank
    _markerGeneration++;
    

    for (int i = 0; i < (routesCache.length / 3); i++) {
      // debugPrint("Reloading markers (staggered) for route ${routesCache[i].routeId}");
      // await reloadMarkersForRoutes([routesCache[i]]);
      await reloadMarkersForRoutes(routesCache.sublist(i * 3, math.min((i + 1) * 3, routesCache.length)));
      // if (isVisible) onUpdate();
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
