import 'dart:math';
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
  static const int ANIMATION_DURATION = 8000; //4000; // Animation duration in ms

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
          LatLng? oldPosition = busAnimationCache[busId]?.prevBus?.position;
          LatLng? newPosition = busAnimationCache[busId]?.bus.position;

          interpolatedPosition = LatLng(
            animatedPercentage * (newPosition!.latitude - oldPosition!.latitude) + oldPosition!.latitude,
            animatedPercentage * (newPosition!.longitude - oldPosition!.longitude) + oldPosition!.longitude
          );

          busAnimationCache[busId]?.lastInterpolatedPosition = interpolatedPosition;
          // TODO: Figure out why the buses are still jumpy? They might not be anymore actually

          // NOTE: Combined with the "has the bus moved at all" check, this might cause problems if the bus is staying still at a stop light? Double check this

          double headingDelta = (busAnimationCache[busId]!.bus.heading - busAnimationCache[busId]!.prevBus!.heading);

          if (headingDelta.abs() > (360 + headingDelta).abs()) {
            // Might need to fix this
            headingDelta = 360 + headingDelta; // Turn the tightest direction possible
          }

          if ((headingDelta).abs() < 120) {
            // Don't animate heading changes of more than 120 degrees to avoid weird spinning if the bus turns 180

            interpolatedHeading = animatedPercentage * (busAnimationCache[busId]!.bus.heading - busAnimationCache[busId]!.prevBus!.heading) + busAnimationCache[busId]!.prevBus!.heading;
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
        onUpdate(); // Tell the CompositeMapWidget to update (CompositeMapWidget calls setState inside onUpdate)
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
  @override
  bool isVisible = true;
  @override
  Set<Polyline> polylines = {};
  @override
  Set<Marker> markers = {};
  @override
  Function() onUpdate = () {};
  
  void setOnUpdate(Function() callback) {
    debugPrint("****** got setOnUpdate call!");
    onUpdate = callback;
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


class CompositeMapWidgetState extends State<CompositeMapWidget> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> allMarkers = {};
  Set<Polyline> allPolylines = {};


  void reloadMap() {
    // debugPrint("******* Got reloadMap() call!");
    // _mapController.
    setState(() {}); // Rebuild with updated markers
  }

  @override
  initState() {
    super.initState();
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
        onMapCreated:(controller) {
          _mapController = controller;
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