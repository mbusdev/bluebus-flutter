import 'dart:math';

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

class BusAnimationState {
  Bus?
  prevBus; // Used to animate from the previous position to current position
  Bus bus;
  // BitmapDescriptor busIcon;
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
    // required this.busIcon,
    required this.markerId,
    this.lastUpdated = 0,
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
  Function(LatLng) showRipple = (LatLng location) {
    debugPrint("Error: showRipple called but callback was not registered!");
  };

  @override
  Set<Polyline> polylines = {};

  bool isAnimating = false;
  late Animation<double> animation;
  int nextAnimationFrameTime = 0;
  int animationStartedTime = 0;
  static const int FRAME_DURATION = 100; // Frame duration in ms for animations
  static const int ANIMATION_DURATION =
      11000; //4000; // Animation duration in ms

  AnimationController? controller;
  List<Bus> buses = [];
  Set<String> selectedRoutes = {};
  TickerProvider? tickerProvider;

  Map<String, BusAnimationState> busAnimationCache =
      {}; // Maps Bus ID -> BusAnimationState

  Function(Bus b) onBusClicked = (Bus b) {
    debugPrint("Error: onBusClicked callback was called but never intiialized");
  };

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  @override
  void setShowRipple(Function(LatLng) callback) {
    showRipple = callback;
  }

  void initWithTickerProvider(TickerProvider tickerProviderIn) {
    tickerProvider = tickerProviderIn;
    controller = AnimationController(
      duration: const Duration(milliseconds: ANIMATION_DURATION),
      vsync: tickerProvider!,
    );
  }

  void init(
    List<Bus> buses_in,
    Set<String> selectedRoutes_in,
    Function(Bus b) onBusClicked_in,
  ) {
    buses = buses_in;
    selectedRoutes = selectedRoutes_in;
    onBusClicked = onBusClicked_in;

    // MapImageService.loadData(); // Testing NOT including this since it's already happening inside map_screen.dart on app load. Looks like commenting this out fixed the weird marker problems
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
      onTap: () {
        showRipple(bus.position);
        onBusClicked(bus);
      },
    );
  }

  void updateAnimation() {
    DateTime now = DateTime.now();

    markers = busAnimationCache.keys
        .where((String busId) {
          return selectedRoutes.contains(busAnimationCache[busId]?.bus.routeId);
        })
        .map((String busId) {
          LatLng interpolatedPosition;
          double interpolatedHeading = busAnimationCache[busId]!.bus.heading;
          double animatedPercentage = min(
            (now.millisecondsSinceEpoch -
                    busAnimationCache[busId]!.lastUpdated) /
                ANIMATION_DURATION,
            1.0,
          );

          if (busAnimationCache[busId]?.prevBus == null) {
            // If this is the first time we've seen this bus, there won't be a previous position to animate from
            interpolatedPosition = busAnimationCache[busId]!.bus.position;
          } else {
            LatLng? oldPosition = busAnimationCache[busId]?.fromPosition;
            LatLng? newPosition = busAnimationCache[busId]?.toPosition;

            interpolatedPosition = LatLng(
              animatedPercentage *
                      (newPosition!.latitude - oldPosition!.latitude) +
                  oldPosition!.latitude,
              animatedPercentage *
                      (newPosition!.longitude - oldPosition!.longitude) +
                  oldPosition!.longitude,
            );

            busAnimationCache[busId]?.lastInterpolatedPosition =
                interpolatedPosition;
            // TODO: Figure out why the buses are still jumpy? They might not be anymore actually

            // NOTE: Combined with the "has the bus moved at all" check, this might cause problems if the bus is staying still at a stop light? Double check this

            double headingDelta =
                (busAnimationCache[busId]!.fromHeading! -
                busAnimationCache[busId]!.toHeading!);

            if (headingDelta.abs() > (360 + headingDelta).abs()) {
              // Might need to fix this
              headingDelta =
                  360 + headingDelta; // Turn the tightest direction possible
            }

            if ((headingDelta).abs() < 120) {
              // Don't animate heading changes of more than 120 degrees to avoid weird spinning if the bus turns 180

              interpolatedHeading =
                  animatedPercentage *
                      (busAnimationCache[busId]!.toHeading! -
                          busAnimationCache[busId]!.fromHeading!) +
                  busAnimationCache[busId]!.fromHeading!;
            }
          }

          busAnimationCache[busId]?.lastInterpolatedHeading =
              interpolatedHeading;
          busAnimationCache[busId]?.lastInterpolatedPosition =
              interpolatedPosition;

          return Marker(
            flat: true,
            zIndexInt:
                busId.hashCode.abs() %
                1000, // To prevent buses from fighting over who's on top and causing flickering
            markerId: busAnimationCache[busId]!.markerId,
            consumeTapEvents: true,
            position: interpolatedPosition,
            // icon: busAnimationCache[busId]!.busIcon,
            icon: MapImageService.getBusIcon(busAnimationCache[busId]!.bus),
            rotation: interpolatedHeading,
            anchor: const Offset(0.5, 0.5), // Center the icon on the position
            onTap: () {
              showRipple(interpolatedPosition);
              try {
                Haptics.vibrate(HapticsType.light);
              } catch (e) {}
              onBusClicked(busAnimationCache[busId]!.bus);
              // _showBusSheet(bus.id);
            },
          );

          // return Marker();
        })
        .toSet();

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
    if (animationStartedTime + ANIMATION_DURATION >
        now.millisecondsSinceEpoch) {
      return; // Prevent starting the same animation twice if startAnimation() gets multiple calls
    }

    if (controller == null) return;

    animationStartedTime = now.millisecondsSinceEpoch;

    // TODO: Don't start the animation if it's already going

    // controller?.reset(); // Stop all previous animations
    // WHY DOES IT BREAK WHEN THIS ISN'T HERE????

    if (isAnimating) return;

    controller?.reset();
    isAnimating = true;

    animation = Tween<double>(begin: 0, end: 1).animate(controller!)
      ..addListener(() {
        DateTime now = DateTime.now();
        if (now.millisecondsSinceEpoch < nextAnimationFrameTime) return;
        nextAnimationFrameTime =
            now.millisecondsSinceEpoch + FRAME_DURATION; // 100ms frametimes

        updateAnimation();
        if (isVisible) {
          onUpdate(); // Tell the CompositeMapWidget to update (CompositeMapWidget calls setState inside onUpdate)
        }
      });

    animation.addStatusListener((AnimationStatus status) {});

    controller?.forward();
    controller?.repeat();

  }

  void reload() {
    // Called when parent has new live bus GPS data to tell us about!

    // null case or error contacting server case
    if (buses == []) return;

    DateTime now = DateTime.now();

    // markers = buses
    buses.where((bus) => selectedRoutes.contains(bus.routeId))
    // .map((bus) {
    .forEach((bus) {
      // Update all cached markers with new location data (location is contained inside bus object)
      if (busAnimationCache.containsKey(bus.id) &&
          busAnimationCache[bus.id]!.lastUpdated + 30000 >
              now.millisecondsSinceEpoch) {
        // If the last bus position is super old and we try to animate it, it appears to "skate" across the map from its old position to its new position, ignoring streets entirely. It looks really funky, so if the last updated time is more than 30 seconds old, skip the animation

        if (busAnimationCache[bus.id]?.bus.position == bus.position &&
            busAnimationCache[bus.id]?.bus.heading == bus.heading &&
            busAnimationCache[bus.id]!.lastUpdated + ANIMATION_DURATION + 200 >
                now.millisecondsSinceEpoch) {
          // If the bus position hasn't changed and the bus was updated recently, skip it!
          return;
        }

        busAnimationCache[bus.id]!.lastUpdated = now.millisecondsSinceEpoch;

        busAnimationCache[bus.id]?.prevBus = busAnimationCache[bus.id]?.bus;
        busAnimationCache[bus.id]?.bus = bus;
        // busAnimationCache[bus.id]?.busIcon = MapImageService.getBusIcon(bus);

        busAnimationCache[bus.id]?.fromPosition =
            busAnimationCache[bus.id]?.lastInterpolatedPosition;
        busAnimationCache[bus.id]?.fromHeading =
            busAnimationCache[bus.id]?.lastInterpolatedHeading;
        busAnimationCache[bus.id]?.toPosition = bus.position;
        busAnimationCache[bus.id]?.toHeading = bus.heading;
      } else {
        // If we get here, the previous position either doesn't exist or is too old. Create a new BusAnimationState from scratch

        busAnimationCache[bus.id] = BusAnimationState(
          bus: bus,
          // busIcon: MapImageService.getBusIcon(bus),
          markerId: MarkerId('bus_${bus.id}'),
          lastUpdated: now.millisecondsSinceEpoch,
        );
        // // TODO: This runs for EVERY bus route, so even if we're already downloading the icon for a Bursley-Baits bus, it'll try to download the icon for EVERY Bursley-Baits bus on the map
        // // NEXT STEPS TODO: Figure out if the cache is working, and do some live testing on my phone to make sure.
        // if (!MapImageService.isBusIconAvailable(bus)) {
        //   MapImageService.ensureRouteIconIsLoaded(bus.routeId).then((
        //     BitmapDescriptor? icon,
        //   ) {
        //     // Add the icon to the cache when it's ready
        //     if (icon == null) return;

        //     for (final state in busAnimationCache.values) {
        //       if (state.bus.routeId == bus.routeId) {
        //         state.busIcon = icon;
        //       }
        //     }
        //   });
        // }
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
