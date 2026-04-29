import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

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
  void dispose() {}
}
// TODO: Extend the MapController back to map_screen.dart so it can move the camera and stuff
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
    if (isVisible) onUpdate();
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

      if (!markersCache.containsKey(routeKey)) { // Prevent duplicate copies of the same stop on top of each other
        markersCache[routeKey] = {};
        for (final stop in r.stops) { // iterate through all stops in this route
          // TODO: Implement favorite stops
          // final isFavorite = _favoriteStops.contains(stop.id);
          
          final marker = Marker(
            zIndexInt: 10, // Put bus stops on top of buses
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

    polylinesCache.clear();

    for (final r in routesCache) {
      if (!selectedRoutes.contains(r.routeId)) continue; // Skip deselected routes

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

  void cacheRoutes(List<BusRouteLine> routes) {
    debugPrint("******* Got cacheRoutes call!!");
    // Called from inside _loadAllData() inside map_screen.dart
    routesCache = routes;

    // TODO: Make the parent (map_screen.dart) pass in the list of filtered route IDs and as soon as that list changes call some sort of reloadMarkers()

    // TODO: Update the map controller here
    debugPrint("Calling onUpdate: ${onUpdate}");

    reloadMarkers();
    reloadPolylines();

    if (isVisible) onUpdate();
  }

  
}

class BusAnimationState {
  Bus? prevBus; // Used to animate from the previous position to current position
  Bus bus;
  BitmapDescriptor busIcon;
  MarkerId markerId;
  int lastUpdated = 0;

  LatLng? lastInterpolatedPosition;
  double? lastInterpolatedHeading;
  LatLng? fromPosition;
  double? fromHeading;
  LatLng? toPosition;
  double? toHeading;

  BusAnimationState({
    required this.bus,
    required this.busIcon,
    required this.markerId,
    this.lastUpdated = 0
  }) {
    toHeading = bus.heading;
    toPosition = bus.position;
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

  bool isAnimating = false;
  late Animation<double> animation;
  int nextAnimationFrameTime = 0;
  int animationStartedTime = 0;
  static const int FRAME_DURATION = 100; // Frame duration in ms for animations
  static const int ANIMATION_DURATION = 11000; //4000; // Animation duration in ms

  AnimationController? controller;
  List<Bus> buses = [];
  Set<String> selectedRoutes = {};
  TickerProvider? tickerProvider;



  Map<String, BusAnimationState> busAnimationCache = {}; // Maps Bus ID -> BusAnimationState

  Function(Bus b) onBusClicked = (Bus b) {
    debugPrint("Error: onBusClicked callback was called but never intiialized");
  };

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  void initWithTickerProvider(TickerProvider tickerProviderIn) {
    debugPrint("******* Initting with animation controller!!");
    tickerProvider = tickerProviderIn;
    controller = AnimationController(duration: const Duration(milliseconds: ANIMATION_DURATION), vsync: tickerProvider!);

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

  void updateAnimation() {

    // debugPrint("* updateAnimation call! busAnimationCache has ${busAnimationCache.keys.length} keys");
    // debugPrint("        Animation value is ${animation.value}");
    // debugPrint("* selectedRoutes is ${selectedRoutes}");

    DateTime now = DateTime.now();

    markers = busAnimationCache.keys.where((String busId) {
      // debugPrint("Checking to see if we should add marker ${busAnimationCache[busId]?.bus.routeId}: ${selectedRoutes.contains(busAnimationCache[busId]?.bus.routeId)}");
      return selectedRoutes.contains(busAnimationCache[busId]?.bus.routeId);
  })
      .map((String busId) {
        LatLng interpolatedPosition;
        // debugPrint("Adding marker for ${busId}");
        double interpolatedHeading = busAnimationCache[busId]!.bus.heading;
        double animatedPercentage = min((now.millisecondsSinceEpoch - busAnimationCache[busId]!.lastUpdated) / ANIMATION_DURATION, 1.0);

        // debugPrint("animatedPercentage is ${animatedPercentage.toStringAsFixed(2)}");

        if (busAnimationCache[busId]?.prevBus == null) {
          // If this is the first time we've seen this bus, there won't be a previous position to animate from
          interpolatedPosition = busAnimationCache[busId]!.bus.position;
        } else {
          LatLng? oldPosition = busAnimationCache[busId]?.fromPosition;
          LatLng? newPosition = busAnimationCache[busId]?.toPosition;

          interpolatedPosition = LatLng(
            animatedPercentage * (newPosition!.latitude - oldPosition!.latitude) + oldPosition!.latitude,
            animatedPercentage * (newPosition!.longitude - oldPosition!.longitude) + oldPosition!.longitude
          );

          busAnimationCache[busId]?.lastInterpolatedPosition = interpolatedPosition;
          // TODO: Figure out why the buses are still jumpy? They might not be anymore actually

          // NOTE: Combined with the "has the bus moved at all" check, this might cause problems if the bus is staying still at a stop light? Double check this

          double headingDelta = (busAnimationCache[busId]!.fromHeading! - busAnimationCache[busId]!.toHeading!);

          if (headingDelta.abs() > (360 + headingDelta).abs()) {
            // Might need to fix this
            headingDelta = 360 + headingDelta; // Turn the tightest direction possible
          }

          if ((headingDelta).abs() < 120) {
            // Don't animate heading changes of more than 120 degrees to avoid weird spinning if the bus turns 180

            interpolatedHeading = animatedPercentage * (busAnimationCache[busId]!.toHeading! - busAnimationCache[busId]!.fromHeading!) + busAnimationCache[busId]!.fromHeading!;
          }
        }

        busAnimationCache[busId]?.lastInterpolatedHeading = interpolatedHeading;
        busAnimationCache[busId]?.lastInterpolatedPosition = interpolatedPosition;

        return Marker(
          flat: true,
          zIndexInt: 1,
          markerId: busAnimationCache[busId]!.markerId,
          consumeTapEvents: true,
          position: interpolatedPosition,
          icon: busAnimationCache[busId]!.busIcon,
          rotation: interpolatedHeading,
          anchor: const Offset(0.5, 0.5), // Center the icon on the position
          onTap: () {
            try {
              Haptics.vibrate(HapticsType.light);
            } catch (e) {}
            onBusClicked(busAnimationCache[busId]!.bus);
            // _showBusSheet(bus.id);
          },
        );

        // return Marker();
      }).toSet();

    // debugPrint("***** Finished updateAnimation() call, we now have ${markers.length} markers");

    // markers = buses
      // busAnimationCache.where((bus) => selectedRoutes.contains(bus.routeId))
      // // .map((bus) {
      // .forEach((bus) {

      //   // Update all cached markers with new location data (location is contained inside bus object)
      //   if (busAnimationCache.containsKey(bus.id)) {
      //     busAnimationCache[bus.id]?.prevBus = busAnimationCache[bus.id]?.bus;
      //     busAnimationCache[bus.id]?.bus = bus;
      //   } else {
      //     busAnimationCache[bus.id] = BusAnimationState(
      //       bus: bus,
      //       busIcon: MapImageService.getBusIcon(bus),
      //       markerId: MarkerId('bus_${bus.id}')
      //     );
      //   }
      // });

      // //TODO: Start the animation here!
      // startAnimation();

      //   // Use route specific bus icon if available, otherwise fallback to default
      //   BitmapDescriptor? busIcon = MapImageService.getBusIcon(bus);

      //   // NEXT STEPS TODO: Get bus animations working on android, and get the live updating to work!

      //   // Maybe try Project SmoothBus(TM) again?

      //   return Marker(
      //     flat: true,
      //     markerId: MarkerId('bus_${bus.id}'),
      //     consumeTapEvents: true,
      //     position: bus.position,
      //     icon: busIcon,
      //     rotation: bus.heading,
      //     anchor: const Offset(0.5, 0.5), // Center the icon on the position
      //     onTap: () {
      //       try {
      //         Haptics.vibrate(HapticsType.light);
      //       } catch (e) {}
      //       onBusClicked(bus);
      //       // _showBusSheet(bus.id);
      //     },
      //   );
      // })
      // .toSet();
  }

  void startAnimation() {
    DateTime now = DateTime.now();
    if (animationStartedTime + ANIMATION_DURATION > now.millisecondsSinceEpoch) {
      return; // Prevent starting the same animation twice if startAnimation() gets multiple calls
    }

    // debugPrint("* Starting animation! Last animation was ${(now.millisecondsSinceEpoch - animationStartedTime) / 1000}s ago");
    if (controller == null) return;
    // if (controller!.isAnimating) return; //Animation runs infinitely, so we only start it once

    animationStartedTime = now.millisecondsSinceEpoch;

    // TODO: Don't start the animation if it's already going


    // controller?.reset(); // Stop all previous animations
    // WHY DOES IT BREAK WHEN THIS ISN'T HERE????

    if (isAnimating) return;

    controller?.reset();
    isAnimating = true;

    animation = Tween<double>(begin: 0, end: 1).animate(controller!)
      ..addListener(() {
        // debugPrint("tick");
        DateTime now = DateTime.now();
        if (now.millisecondsSinceEpoch < nextAnimationFrameTime) return;
        nextAnimationFrameTime = now.millisecondsSinceEpoch + FRAME_DURATION; // 100ms frametimes

        // debugPrint("****** Got animation tick!");
        updateAnimation();
        if (isVisible) onUpdate(); // Tell the CompositeMapWidget to update (CompositeMapWidget calls setState inside onUpdate)
      });

    animation.addStatusListener((AnimationStatus status) {
      // if (status == AnimationStatus.completed) {
      //   debugPrint("********* RESTARTING ANIMATION");
      //   controller?.forward();
      // }
    });

    controller?.forward();
    controller?.repeat();
    
    
    debugPrint("***** Finished starting animation");
  }

  void reload() { // Called when parent has new live bus GPS data to tell us about!

    // null case or error contacting server case
    if (buses == []) return;

    DateTime now = DateTime.now();

    // markers = buses
      buses.where((bus) => selectedRoutes.contains(bus.routeId))
      // .map((bus) {
      .forEach((bus) {

        // Update all cached markers with new location data (location is contained inside bus object)
        if (busAnimationCache.containsKey(bus.id)
          && busAnimationCache[bus.id]!.lastUpdated + 30000 > now.millisecondsSinceEpoch) {
            // If the last bus position is super old and we try to animate it, it appears to "skate" across the map from its old position to its new position, ignoring streets entirely. It looks really funky, so if the last updated time is more than 30 seconds old, skip the animation
          
          if (busAnimationCache[bus.id]?.bus.position == bus.position
            && busAnimationCache[bus.id]?.bus.heading == bus.heading
            && busAnimationCache[bus.id]!.lastUpdated + ANIMATION_DURATION + 200> now.millisecondsSinceEpoch) {
              // debugPrint(">>>> Bus position has not changed! Skipping animation for ${bus.id}");
            // If the bus position hasn't changed and the bus was updated recently, skip it!
            return;
          }

          busAnimationCache[bus.id]!.lastUpdated = now.millisecondsSinceEpoch;


          busAnimationCache[bus.id]?.prevBus = busAnimationCache[bus.id]?.bus;
          busAnimationCache[bus.id]?.bus = bus;
          busAnimationCache[bus.id]?.busIcon = MapImageService.getBusIcon(bus);

          busAnimationCache[bus.id]?.fromPosition = busAnimationCache[bus.id]?.lastInterpolatedPosition;
          busAnimationCache[bus.id]?.fromHeading = busAnimationCache[bus.id]?.lastInterpolatedHeading;
          busAnimationCache[bus.id]?.toPosition = bus.position;
          busAnimationCache[bus.id]?.toHeading = bus.heading;

        } else {
          // If we get here, the previous position either doesn't exist or is too old. Create a new BusAnimationState from scratch

          busAnimationCache[bus.id] = BusAnimationState(
            bus: bus,
            busIcon: MapImageService.getBusIcon(bus),
            markerId: MarkerId('bus_${bus.id}'),
            lastUpdated: now.millisecondsSinceEpoch
          );
        }
      });

      //TODO: Start the animation here!
      startAnimation();

        // // Use route specific bus icon if available, otherwise fallback to default
        // BitmapDescriptor? busIcon = MapImageService.getBusIcon(bus);

        // // NEXT STEPS TODO: Get bus animations working on android, and get the live updating to work!

        // // Maybe try Project SmoothBus(TM) again?

        // return Marker(
        //   flat: true,
        //   markerId: MarkerId('bus_${bus.id}'),
        //   consumeTapEvents: true,
        //   position: bus.position,
        //   icon: busIcon,
        //   rotation: bus.heading,
        //   anchor: const Offset(0.5, 0.5), // Center the icon on the position
        //   onTap: () {
        //     try {
        //       Haptics.vibrate(HapticsType.light);
        //     } catch (e) {}
        //     onBusClicked(bus);
        //     // _showBusSheet(bus.id);
        //   },
        // );
      // })
      // .toSet();
  }


  // TODO: Dispose of the AnimationController when done!
  void dispose() {
    controller?.dispose();
  }

}

class JourneyLayer extends CompositeMapLayer {
  // maximum allowed distance (meters) from a stop to a candidate polyline point
  static const double _maxMatchDistanceMeters = 150.0;


  @override
  bool isVisible = true;
  @override
  Set<Polyline> polylines = {};
  @override
  Set<Marker> markers = {};
  @override
  Function() onUpdate = () {};

  Function(String s) _showBusSheet = (String s) {debugPrint("Error: _showBusSheet was called but callback was never set");};

  BitmapDescriptor? _getOn;
  BitmapDescriptor? _getOff;
  BitmapDescriptor? _destination;
  BitmapDescriptor? _start;

  Set<String> activeJourneyBusIds = {};
  Set<String> activeJourneyRoutes = {};
  Set<Marker> liveBusMarkers = {};

  Map<String, BusRouteLine> routesCache = {};
  BuildContext? context;

  GoogleMapController? _mapController;

  void setMapController(GoogleMapController mapController_in) {
    _mapController = mapController_in;
  }

  void init(Function(String s) showBusSheet_in, Set<String> activeJourneyBusIds_in, Set<String> activeJourneyRoutes_in, BuildContext context_in) {
    // activeJourneyBusIds = activeJourneyBusIds_in;
    // activeJourneyRoutes = activeJourneyRoutes_in;
    // TODO: Get rid of activeJourneyBusIds and activeJourneyRoutes as they're passed in here
    _showBusSheet = showBusSheet_in;
    context = context_in;
    loadMarkers();
  }

  Future<void> loadMarkers() async {
    _getOn = await MapImageService.resizeImage(await rootBundle.load('assets/getOn.png'));
    _getOff = await MapImageService.resizeImage(await rootBundle.load('assets/getOff.png'));
    _destination = await MapImageService.resizeImage(await rootBundle.load('assets/destination.png'));
    _start = await MapImageService.resizeImage(await rootBundle.load('assets/start.png'));
  }
  
  void setOnUpdate(Function() callback) {
    debugPrint("****** got setOnUpdate call!");
    onUpdate = callback;
  }

  void refreshLiveBusMarkers(List<Bus> allBuses) {
    liveBusMarkers.clear();
    for (final bus in allBuses) {
      // Show buses that are on routes used in the journey
      if (activeJourneyBusIds.contains(bus.id)) {
        BitmapDescriptor busIcon = MapImageService.getBusIcon(bus);
        
        liveBusMarkers.add(
          Marker(
            flat: true,
            markerId: MarkerId('journey_bus_${bus.id}'),
            consumeTapEvents: true,
            position: bus.position,
            icon: busIcon!,
            rotation: bus.heading,
            anchor: const Offset(0.5, 0.5),
            onTap: () => _showBusSheet(bus.id),
          ),
        );
      }
    }
  }

  void setRoutesCache(List<BusRouteLine> routes) {
    for (BusRouteLine l in routes) {
      routesCache[l.routeId] = l;
    }
  }



  // Haversine distance between two LatLngs in meters
  double _haversineDistanceMeters(LatLng a, LatLng b) {
    const R = 6371000; // Earth radius in meters
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;

    final sa =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(sa), math.sqrt(1 - sa));
    return R * c;
  }

  // Find nearest index and its distance on polyline to target. Returns a pair [index, distanceMeters]
  List<dynamic> _nearestIndexAndDistanceOnPolyline(
    List<LatLng> poly,
    LatLng target,
  ) {
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < poly.length; i++) {
      final p = poly[i];
      final d = _haversineDistanceMeters(p, target);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return [bestIdx, bestDist];
  }

  // Helper to extract a contiguous segment from polyline points between two latlngs
  // Return null if indices are invalid or segment is too short.
  List<LatLng>? _extractRouteSegment(
    List<LatLng> poly,
    LatLng start,
    LatLng end,
  ) {
    debugPrint("extractRouteSegment call!!!");
    final sRes = _nearestIndexAndDistanceOnPolyline(poly, start);
    final eRes = _nearestIndexAndDistanceOnPolyline(poly, end);
    debugPrint("*** sRes = ${sRes}, eRes = ${eRes}");
    final si = sRes[0] as int;
    final ei = eRes[0] as int;
    final sDist = sRes[1] as double;
    final eDist = eRes[1] as double;

    // If either nearest point is too far from the stop, we consider this polyline not a match
    if (sDist > _maxMatchDistanceMeters || eDist > _maxMatchDistanceMeters)
      return null;

    debugPrint("We have valid coords!");

    if (si == ei) return null;

    // Ensure start < end in index space, if reversed, flip the sublist
    if (si < ei) {
      return poly.sublist(si, ei + 1);
    } else {
      final seg = poly.sublist(ei, si + 1);
      return seg.reversed.toList();
    }
  }


  Future<void> addBusLegMarkersAndPolylines(Leg leg, Journey journey, int legIndex) async {
    // This accepts a bus leg that goes from, e.g. CCTC (C251) through several stops to a destination, e.g. Stop C251
    // and adds the necessary markers and polylines to the markers and polylines Sets

    if (leg.rt != null) activeJourneyRoutes.add(leg.rt!);
    if (leg.trip != null) activeJourneyBusIds.add(leg.trip!.vid);

    BusRouteLine? line = routesCache[leg.rt];

    debugPrint("Tracing path from ${leg.originID} to ${leg.destinationID}");

    final LatLng? startLatLng = getLatLongFromStopID(leg.originID);
    final LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

    if (startLatLng != null && endLatLng != null && line?.points != null) {
      List<LatLng>? segment = _extractRouteSegment(line!.points, startLatLng, endLatLng);
      if (segment == null) {
        debugPrint("ERROR: Line segment is null!");

        // If something went wrong tracing streets between stops, just draw a straight
        //  line between the start and end
        final polyline = Polyline(
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
          points: [startLatLng, endLatLng],
          color: RouteColorService.getRouteColor(leg.rt!),
          width: 6,
        );
        polylines.add(polyline);
      } else {
        final polyline = Polyline(
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
          points: segment,
          color: RouteColorService.getRouteColor(leg.rt!),
          width: 6,
        );
        polylines.add(polyline);
      }

      debugPrint("Trying to add markers");
      // add stop markers at endpoints of the segment (boarding/getting off)
      if ((segment?.first != null || startLatLng != null)) {
        // Making sure the marker has a valid location
        debugPrint("Can add start/end markers!");

        BitmapDescriptor iconBitmap = await RouteIcon.small(leg.rt!).toBitmapDescriptor();

        // TODO: See what the UI team says about this--if it looks good, add an extra method to the RouteIcon class that generates a bitmap instead of having to render this whole thing to the widget tree (it'll be MUCH faster)

        markers.add(
          Marker(
            flat: true,
            markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
            position: segment?.first ?? startLatLng,
            icon:
                // _getOn ??
                iconBitmap ??

                BitmapDescriptor.defaultMarkerWithHue(
                  colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                ),
            anchor: Offset(0.5, 0.5),
          ),
        );

        // markers.add(
        //   Marker(
        //     flat: true,
        //     markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
        //     position: segment?.first ?? startLatLng,
        //     icon:
        //         _getOn ??
        //         BitmapDescriptor.defaultMarkerWithHue(
        //           colorToHue(RouteColorService.getRouteColor(leg.rt!)),
        //         ),
        //   ),
        // );
      }
      if ((segment?.last != null || endLatLng != null)) {
        // Making sure the marker has a valid location
        // markers.add(Marker(
        //     flat: true,
        //     markerId: MarkerId(
        //       'journey_stop_${leg.destinationID}_$legIndex',
        //     ),
        //     position: segment?.last ?? endLatLng,
        //     icon:
        //         _getOff ??
        //         BitmapDescriptor.defaultMarkerWithHue(
        //           colorToHue(RouteColorService.getRouteColor(leg.rt!)),
        //         ),
        //   ),
        // );
      }
    }



  }

  void addWalkingLegMarkersAndPolylines(Leg leg, Journey journey, int legIndex) {
    // Walking legs add a dotted line between origin and destination
    // First try to get the locations from origin and destination IDs
    LatLng? startLatLng = getLatLongFromStopID(leg.originID);
    LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

    debugPrint("**** Adding walking leg markers! from ${startLatLng} to ${endLatLng}");

    // Walking leg information

    // Locations were not found, could be a building or custom location
    // In this case, we need to look for coordinates in previous/next legs
    // Also handle virtual origin/destination from the directions request

    // TODO: Handle these edge cases

    // if (startLatLng == null) {
    //   // resolve virtual origin
    //   if (leg.originID == 'VIRTUAL_ORIGIN' &&
    //       _lastJourneyRequestOrigin != null) {
    //     startLatLng = LatLng(
    //       _lastJourneyRequestOrigin!['lat']!,
    //       _lastJourneyRequestOrigin!['lon']!,
    //     );
    //   } else if (leg.originID == 'VIRTUAL_DESTINATION' &&
    //       _lastJourneyRequestDest != null) {
    //     startLatLng = LatLng(
    //       _lastJourneyRequestDest!['lat']!,
    //       _lastJourneyRequestDest!['lon']!,
    //     );
    //   }
    // }

    // If still unresolved and this is a virtual origin, attempt to use device location
    // if (startLatLng == null && leg.originID == 'VIRTUAL_ORIGIN') {
    //   try {
    //     final pos = await Geolocator.getCurrentPosition().timeout(
    //       Duration(seconds: 3),
    //     );
    //     startLatLng = LatLng(pos.latitude, pos.longitude);
    //   } catch (e) {
    //     // ignore GPS resolution failure
    //   }
    // }


    // NEXT STEPS TODO: Get these walking lines working and see if I can fix the straight-line bus segment problem (where it says ERROR: Line segment is null!)

    if (startLatLng == null && legIndex > 0) {
      // Try to get end location from previous leg
      final prevLeg = journey.legs[legIndex - 1];
      startLatLng = getLatLongFromStopID(prevLeg.destinationID);
    }

    // if (endLatLng == null) {
    //   // resolve virtual destination
    //   if (leg.destinationID == 'VIRTUAL_DESTINATION' &&
    //       _lastJourneyRequestDest != null) {
    //     endLatLng = LatLng(
    //       _lastJourneyRequestDest!['lat']!,
    //       _lastJourneyRequestDest!['lon']!,
    //     );
    //   } else if (leg.destinationID == 'VIRTUAL_ORIGIN' &&
    //       _lastJourneyRequestOrigin != null) {
    //     endLatLng = LatLng(
    //       _lastJourneyRequestOrigin!['lat']!,
    //       _lastJourneyRequestOrigin!['lon']!,
    //     );
    //   }
    // }

    // If still unresolved and this is a virtual destination, attempt device location fallback
    // if (endLatLng == null && leg.destinationID == 'VIRTUAL_DESTINATION') {
    //   try {
    //     final pos = await Geolocator.getCurrentPosition().timeout(
    //       Duration(seconds: 3),
    //     );
    //     endLatLng = LatLng(pos.latitude, pos.longitude);
    //   } catch (e) {
    //     print('Could not resolve VIRTUAL_DESTINATION via device GPS: $e');
    //   }
    // }

    // if (endLatLng == null && legIndex < journey.legs.length - 1) {
    //   // Try to get start location from next leg
    //   final nextLeg = journey.legs[legIndex + 1];
    //   endLatLng = getLatLongFromStopID(nextLeg.originID);
    // }

    // // Check if we have both coordinates before creating walking polyline
    // if (startLatLng != null && endLatLng != null) {
    //   List<LatLng> pts = [];
    //   if (leg.pathCoords != null && leg.pathCoords!.isNotEmpty) {
    //     pts = leg.pathCoords!;
    //   } else {
    //     pts = [startLatLng, endLatLng];
    //   }

    List<LatLng> pathCoords = leg.pathCoords ?? [];

    if (leg.pathCoords == null) {
      if (startLatLng != null && endLatLng != null) {
        // If there's no path available, draw a straight line if we can
        pathCoords = [startLatLng, endLatLng];
      }
    }

    // Create a dotted line for walking segments
    final walkingPolyline = Polyline(
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
      polylineId: PolylineId('walking_${journey.hashCode}_$legIndex'),
      points: pathCoords,
      color: (context != null) ? getColor(context!, ColorType.mapWalkingLine) : Colors.black, // Walk line color
      width: 8, // line width
      patterns: [
        PatternItem.dot,
        // PatternItem.dash(30), // Longer dashes
        PatternItem.gap(15), // Longer gaps
      ],
    );

    polylines.add(walkingPolyline);

  }

  void addRouteStartMarker(LatLng position, Journey journey) {
    markers.add(
      Marker(
        flat: true,
        markerId: MarkerId('journey_start_${journey.hashCode}'),
        position: position,
        icon:
            _start ??
          BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
      ),
    );
  }

  void addRouteEndMarker(LatLng position, Journey journey) {
    markers.add(
      Marker(
        flat: true,
        markerId: MarkerId(
          'journey_final_destination_${journey.hashCode}',
        ),
        position: position,
        icon:
          _destination ??
          BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
      ),
    );
  }

  void setJourney(Journey journey, Color walkLineColor) { // Don't stop believin'

    debugPrint("************ got setJourney call");

    // clear previous journey overlay
    polylines.clear();
    markers.clear();
    activeJourneyBusIds.clear();
    activeJourneyRoutes.clear();

    final allPoints = <LatLng>[];

    // First, analyze the journey to find which legs are bus and which are walking

    for (int legIndex = 0; legIndex < journey.legs.length; legIndex++) {
      final leg = journey.legs[legIndex];

      // if (leg.originID == "VIRTUAL_ORIGIN" && leg.pathCoords != null && leg.pathCoords!.isNotEmpty) {
      //   addRouteStartMarker(leg.pathCoords!.first, journey);
      // }
      if (leg.destinationID == "VIRTUAL_DESTINATION" && leg.pathCoords != null && leg.pathCoords!.isNotEmpty) {
        addRouteEndMarker(leg.pathCoords!.last, journey);
      }

      // Determine if this is a walking or bus leg - walking legs don't have rt or trip
      final bool isBusLeg = leg.rt != null && leg.trip != null;
      // Determine leg type for processing

      if (isBusLeg) {

        addBusLegMarkersAndPolylines(leg, journey, legIndex);

        // Add route ID and vehicle ID to active sets for bus filtering
        // if (leg.rt != null) {
        //   activeJourneyRoutes.add(leg.rt!);
        // }
        // if (leg.trip != null) {
        //   activeJourneyBusIds.add(leg.trip!.vid);
        // } // Try to find a cached route polyline segment that follows streets
        // final startLatLng = getLatLongFromStopID(leg.originID);
        // final endLatLng = getLatLongFromStopID(leg.destinationID);

        bool usedRouteGeometry = false;
        // if (startLatLng != null && endLatLng != null) {
        //   final routeVariants = _routePolylines.keys.where(
        //     (key) => key.startsWith('${leg.rt}_'),
        //   );

        //   List<LatLng>? bestSegment;
        //   double? bestLength;

        //   for (final routeKey in routeVariants) {
        //     final poly = _routePolylines[routeKey];
        //     if (poly == null) continue;
        //     final ptsList = poly.points;
        //     if (ptsList.length < 2) continue;

        //     final seg = _extractRouteSegment(ptsList, startLatLng, endLatLng);
        //     if (seg != null && seg.length >= 2) {
        //       // compute approximate length
        //       double len = 0;
        //       for (int i = 1; i < seg.length; i++) {
        //         final a = seg[i - 1];
        //         final b = seg[i];
        //         final dx = a.latitude - b.latitude;
        //         final dy = a.longitude - b.longitude;
        //         len += dx * dx + dy * dy;
        //       }
        //       if (bestSegment == null || len < bestLength!) {
        //         bestSegment = seg;
        //         bestLength = len;
        //       }
        //     }
        //   }

        //   if (bestSegment != null) {
        //     final polyline = Polyline(
        //       polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
        //       points: bestSegment,
        //       color: RouteColorService.getRouteColor(leg.rt!),
        //       width: 6,
        //     );
        //     polylines.add(polyline);

        //     // add stop markers at endpoints of the segment (boarding/getting off)
        //     markers.addAll([
        //       Marker(
        //         flat: true,
        //         markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
        //         position: bestSegment.first,
        //         icon:
        //             _getOn ??
        //             BitmapDescriptor.defaultMarkerWithHue(
        //               colorToHue(RouteColorService.getRouteColor(leg.rt!)),
        //             ),
        //       ),
        //       Marker(
        //         flat: true,
        //         markerId: MarkerId(
        //           'journey_stop_${leg.destinationID}_$legIndex',
        //         ),
        //         position: bestSegment.last,
        //         icon:
        //             _getOff ??
        //             BitmapDescriptor.defaultMarkerWithHue(
        //               colorToHue(RouteColorService.getRouteColor(leg.rt!)),
        //             ),
        //       ),
        //     ]);

        //     allPoints.addAll(bestSegment);
        //     usedRouteGeometry = true;
        //   }
        // }

        if (!usedRouteGeometry) {
          // Fallback to simple path
        //   final pts = <LatLng>[];
        //   bool started = false;
        //   for (final st in leg.trip!.stopTimes) {
        //     if (st.stop == leg.originID) started = true;
        //     if (started) {
        //       final latlng = getLatLongFromStopID(st.stop);
        //       if (latlng != null) {
        //         pts.add(latlng);
        //         allPoints.add(latlng);
        //         _displayedJourneyMarkers.add(
        //           Marker(
        //             flat: true,
        //             markerId: MarkerId('journey_stop_${st.stop}_$legIndex'),
        //             position: latlng,
        //             icon:
        //                 _stopIcon ??
        //                 BitmapDescriptor.defaultMarkerWithHue(
        //                   colorToHue(RouteColorService.getRouteColor(leg.rt!)),
        //                 ),
        //           ),
        //         );
        //       }
        //     }
        //     if (st.stop == leg.destinationID && started) break;
        //   }

        //   if (pts.isNotEmpty) {
        //     final poly = Polyline(
        //       polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
        //       points: pts,
        //       color: RouteColorService.getRouteColor(leg.rt!),
        //       width: 6,
        //     );
        //     _displayedJourneyPolylines.add(poly);
        //   }
        }
      } else {

        addWalkingLegMarkersAndPolylines(leg, journey, legIndex);
        // TODO: Add support for these edge cases

        // // Walking legs add a dotted line between origin and destination
        // // First try to get the locations from origin and destination IDs
        // LatLng? startLatLng = getLatLongFromStopID(leg.originID);
        // LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

        // // Walking leg information

        // // Locations were not found, could be a building or custom location
        // // In this case, we need to look for coordinates in previous/next legs
        // // Also handle virtual origin/destination from the directions request
        // if (startLatLng == null) {
        //   // resolve virtual origin
        //   if (leg.originID == 'VIRTUAL_ORIGIN' &&
        //       _lastJourneyRequestOrigin != null) {
        //     startLatLng = LatLng(
        //       _lastJourneyRequestOrigin!['lat']!,
        //       _lastJourneyRequestOrigin!['lon']!,
        //     );
        //   } else if (leg.originID == 'VIRTUAL_DESTINATION' &&
        //       _lastJourneyRequestDest != null) {
        //     startLatLng = LatLng(
        //       _lastJourneyRequestDest!['lat']!,
        //       _lastJourneyRequestDest!['lon']!,
        //     );
        //   }
        // }

        // // If still unresolved and this is a virtual origin, attempt to use device location
        // if (startLatLng == null && leg.originID == 'VIRTUAL_ORIGIN') {
        //   try {
        //     final pos = await Geolocator.getCurrentPosition().timeout(
        //       Duration(seconds: 3),
        //     );
        //     startLatLng = LatLng(pos.latitude, pos.longitude);
        //   } catch (e) {
        //     // ignore GPS resolution failure
        //   }
        // }

        // if (startLatLng == null && legIndex > 0) {
        //   // Try to get end location from previous leg
        //   final prevLeg = journey.legs[legIndex - 1];
        //   startLatLng = getLatLongFromStopID(prevLeg.destinationID);
        // }

        // if (endLatLng == null) {
        //   // resolve virtual destination
        //   if (leg.destinationID == 'VIRTUAL_DESTINATION' &&
        //       _lastJourneyRequestDest != null) {
        //     endLatLng = LatLng(
        //       _lastJourneyRequestDest!['lat']!,
        //       _lastJourneyRequestDest!['lon']!,
        //     );
        //   } else if (leg.destinationID == 'VIRTUAL_ORIGIN' &&
        //       _lastJourneyRequestOrigin != null) {
        //     endLatLng = LatLng(
        //       _lastJourneyRequestOrigin!['lat']!,
        //       _lastJourneyRequestOrigin!['lon']!,
        //     );
        //   }
        // }

        // // If still unresolved and this is a virtual destination, attempt device location fallback
        // if (endLatLng == null && leg.destinationID == 'VIRTUAL_DESTINATION') {
        //   try {
        //     final pos = await Geolocator.getCurrentPosition().timeout(
        //       Duration(seconds: 3),
        //     );
        //     endLatLng = LatLng(pos.latitude, pos.longitude);
        //   } catch (e) {
        //     print('Could not resolve VIRTUAL_DESTINATION via device GPS: $e');
        //   }
        // }

        // if (endLatLng == null && legIndex < journey.legs.length - 1) {
        //   // Try to get start location from next leg
        //   final nextLeg = journey.legs[legIndex + 1];
        //   endLatLng = getLatLongFromStopID(nextLeg.originID);
        // }

        // // Check if we have both coordinates before creating walking polyline
        // if (startLatLng != null && endLatLng != null) {
        //   List<LatLng> pts = [];
        //   if (leg.pathCoords != null && leg.pathCoords!.isNotEmpty) {
        //     pts = leg.pathCoords!;
        //   } else {
        //     pts = [startLatLng, endLatLng];
        //   }

        //   // Create a dotted line for walking segments
        //   final walkingPolyline = Polyline(
        //     polylineId: PolylineId('walking_${journey.hashCode}_$legIndex'),
        //     points: pts,
        //     color: walkLineColor, // Walk line color
        //     width: 6, // line width
        //     patterns: [
        //       PatternItem.dash(30), // Longer dashes
        //       PatternItem.gap(15), // Longer gaps
        //     ],
        //   );

        //   _displayedJourneyPolylines.add(walkingPolyline);
        //   allPoints.addAll([startLatLng, endLatLng]);

        //   // Only add destination marker if this is the final leg of the journey
        //   if (legIndex == journey.legs.length - 1) {
        //     _displayedJourneyMarkers.add(
        //       Marker(
        //         flat: true,
        //         markerId: MarkerId(
        //           'journey_final_destination_${journey.hashCode}',
        //         ),
        //         position: endLatLng,
        //         icon: BitmapDescriptor.defaultMarkerWithHue(
        //           BitmapDescriptor.hueRed,
        //         ),
        //       ),
        //     );
        //   }

        //   // Add starting marker if this is the first leg of the journey
        //   if (legIndex == 0) {
        //     _displayedJourneyMarkers.add(
        //       Marker(
        //         flat: true,
        //         markerId: MarkerId('journey_start_${journey.hashCode}'),
        //         position: startLatLng,
        //         icon: BitmapDescriptor.defaultMarkerWithHue(
        //           BitmapDescriptor.hueGreen,
        //         ),
        //       ),
        //     );
        //   } // doing this for now bc couldnt figure out marker stuff better
        // }
      }
    }

    // // mark that a journey overlay is active (this will hide other route polylines)
    // _journeyOverlayActive = true;

    // // Build bus markers for buses matching active journey routes
    // // Filter by route first, then optionally by specific vehicle ID if available
    // _displayedJourneyBusMarkers.clear();
    // final busProvider = Provider.of<BusProvider>(context, listen: false);
    // for (final bus in busProvider.buses) {
    //   // Show buses that are on routes used in the journey
    //   if (_activeJourneyRoutes.contains(bus.routeId)) {
    //     _displayedJourneyBusMarkers.add(liveBusesLayer.createBusMarker(bus));
    //   }
    // }

    // // Final debug check
    // // Journey display complete (silently updated internal state)

    // setState(() {
    //   _updateAllDisplayedMarkers();
    // });

    // // Trying to move camera to include the journey bounds
    // if (_mapController != null && allPoints.isNotEmpty) {
    //   try {
    //     double south = allPoints.first.latitude;
    //     double north = allPoints.first.latitude;
    //     double west = allPoints.first.longitude;
    //     double east = allPoints.first.longitude;
    //     for (final p in allPoints) {
    //       south = p.latitude < south ? p.latitude : south;
    //       north = p.latitude > north ? p.latitude : north;
    //       west = p.longitude < west ? p.longitude : west;
    //       east = p.longitude > east ? p.longitude : east;
    //     }

    //     // Adjust bounds to position route in top 1/3 of screen (accounting for bottom sheet)
    //     final latSpan = north - south;
    //     final adjustedSouth =
    //         south - (latSpan) * 2; // Much more padding to bottom
    //     final adjustedNorth = north; // Less padding to top

    //     final bounds = LatLngBounds(
    //       southwest: LatLng(adjustedSouth, west),
    //       northeast: LatLng(adjustedNorth, east),
    //     );

    //     await _mapController!.animateCamera(
    //       CameraUpdate.newLatLngBounds(bounds, 80),
    //     );
    //   } catch (e) {
    //     // fallback to center on first point higher up
    //     if (allPoints.isNotEmpty) {
    //       // Calculate center of route points
    //       double centerLat = 0;
    //       double centerLon = 0;
    //       for (final p in allPoints) {
    //         centerLat += p.latitude;
    //         centerLon += p.longitude;
    //       }
    //       centerLat /= allPoints.length;
    //       centerLon /= allPoints.length;

    //       // Offset the center significantly north to place in top 1/3
    //       final offsetLat = centerLat + 0.008; // Roughly 800m north

    //       await _mapController!.animateCamera(
    //         CameraUpdate.newCameraPosition(
    //           CameraPosition(target: LatLng(offsetLat, centerLon), zoom: 13),
    //         ),
    //       );
    //     }
    //   }
    // }

    if (isVisible) onUpdate(); // Tell the CompositeMapWidget to update
  }

  void clearJourney() {
    markers.clear();
    polylines.clear();
    if (isVisible) onUpdate();
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
  final Function(GoogleMapController) onMapCreated;

// TODO: Implement these methods
  
  
  // final UniversalMapController universalController;
  
  CompositeMapWidget({
    required this.initialCenter,
    required this.mapLayers,
    required this.onMapCreated
  });
  
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return CompositeMapWidgetState();
  }

  
}


class CompositeMapWidgetState extends State<CompositeMapWidget> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> allMarkers = {};
  Set<Polyline> allPolylines = {};


  void reloadMap() {
    // debugPrint("******* Got reloadMap() call!");
    // _mapController.
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

  // debugPrint("******* Got CompositeMapWidget build command! #markers is ${allMarkers.length}");
  


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
        style: isDarkMode(context) ? _darkMapStyle : _lightMapStyle,
        onMapCreated:(GoogleMapController controller) {
          _mapController = controller;
          widget.mapLayers.forEach((CompositeMapLayer layer) {
            if (layer is JourneyLayer) {
              layer.setMapController(controller);
            }
          });
          widget.onMapCreated(controller);
        },
      )
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