import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bluebus/utils/geometry.dart';

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

  Function(String s) _showBusSheet = (String s) {
    debugPrint("Error: _showBusSheet was called but callback was never set");
  };

  BitmapDescriptor? _getOn;
  BitmapDescriptor? _getOff;
  BitmapDescriptor? _destination;
  BitmapDescriptor? _start;

  Set<String> activeJourneyBusIds = {};
  Set<String> activeJourneyRoutes = {};
  Set<Marker> liveBusMarkers = {};

  Map<String, List<BusRouteLine>> routesCache = {};
  BuildContext? context;

  GoogleMapController? _mapController;

  void setMapController(GoogleMapController mapController_in) {
    _mapController = mapController_in;
  }

  void init(
    Function(String s) showBusSheet_in,
    Set<String> activeJourneyBusIds_in,
    Set<String> activeJourneyRoutes_in,
    BuildContext context_in,
  ) {
    // activeJourneyBusIds = activeJourneyBusIds_in;
    // activeJourneyRoutes = activeJourneyRoutes_in;
    // TODO: Get rid of activeJourneyBusIds and activeJourneyRoutes as they're passed in here
    _showBusSheet = showBusSheet_in;
    context = context_in;
    loadMarkers();
  }

  Future<void> loadMarkers() async {
    _getOn = await MapImageService.resizeImage(
      await rootBundle.load('assets/getOn.png'),
    );
    _getOff = await MapImageService.resizeImage(
      await rootBundle.load('assets/getOff.png'),
    );
    _destination = await MapImageService.resizeImage(
      await rootBundle.load('assets/destination.png'),
    );
    _start = await MapImageService.resizeImage(
      await rootBundle.load('assets/start.png'),
    );
  }

  void setOnUpdate(Function() callback) {
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
    routesCache.clear();
    for (BusRouteLine l in routes) {
      routesCache.putIfAbsent(l.routeId, () => []).add(l);
    }
  }

  // Helper to extract a contiguous segment from polyline points between two latlngs
  // Return null if indices are invalid or segment is too short.
  List<LatLng>? _extractRouteSegment(
    List<LatLng> poly,
    LatLng start,
    LatLng end,
  ) {
    final (si, sDist) = start.nearestPolylineIndexAndDistanceDiscrete(poly);
    final (ei, eDist) = end.nearestPolylineIndexAndDistanceDiscrete(poly);

    // If either nearest point is too far from the stop, we consider this polyline not a match
    if (sDist > _maxMatchDistanceMeters || eDist > _maxMatchDistanceMeters) {
      return null;
    }

    if (si == ei) return null;

    // Ensure start < end in index space, if reversed, flip the sublist
    if (si < ei) {
      return poly.sublist(si, ei + 1);
    } else {
      final seg = poly.sublist(ei, si + 1);
      return seg.reversed.toList();
    }
  }

  Future<void> addBusLegMarkersAndPolylines(
    Leg leg,
    Journey journey,
    int legIndex,
  ) async {
    // This accepts a bus leg that goes from, e.g. CCTC (C251) through several stops to a destination, e.g. Stop C251
    // and adds the necessary markers and polylines to the markers and polylines Sets

    if (leg.rt != null) activeJourneyRoutes.add(leg.rt!);
    if (leg.trip != null) activeJourneyBusIds.add(leg.trip!.vid);

    final rt = leg.rt;
    final line = rt != null
      ? determineRouteOfBusLeg(routesCache, rt, leg.originID, leg.destinationID)
      : null;

    // debugPrint("Tracing path from ${leg.originID} to ${leg.destinationID}");

    final LatLng? startLatLng = getLatLongFromStopID(leg.originID);
    final LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

    if (startLatLng != null && endLatLng != null && line?.points != null) {
      List<LatLng>? segment = _extractRouteSegment(
        line!.points,
        startLatLng,
        endLatLng,
      );
      if (segment == null) {
        // debugPrint("ERROR: Line segment is null!");

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

      // add stop markers at endpoints of the segment (boarding/getting off)
      if ((segment?.first != null || startLatLng != null)) {
        // Making sure the marker has a valid location

        // BitmapDescriptor iconBitmap = await RouteIcon.small(
        //   leg.rt!,
        // ).toBitmapDescriptor();

        // TODO: See what the UI team says about this--if it looks good, add an extra method to the RouteIcon class that generates a bitmap instead of having to render this whole thing to the widget tree (it'll be MUCH faster)

        markers.add(
          Marker(
            flat: true,
            markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
            position: segment?.first ?? startLatLng,
            icon:
                _getOn ??
                // iconBitmap ??
                BitmapDescriptor.defaultMarkerWithHue(
                  colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                ),
            anchor: Offset(0.5, 0.5),
          ),
        );
      }
      if ((segment?.last != null || endLatLng != null)) {
        // Making sure the marker has a valid location
        markers.add(
          Marker(
            flat: true,
            markerId: MarkerId('journey_stop_${leg.destinationID}_$legIndex'),
            position: segment?.last ?? endLatLng,
            icon:
                _getOff ??
                BitmapDescriptor.defaultMarkerWithHue(
                  colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                ),
          ),
        );
      }
    }
  }

  void addWalkingLegMarkersAndPolylines(
    Leg leg,
    Journey journey,
    int legIndex,
  ) {
    // Walking legs add a dotted line between origin and destination
    // First try to get the locations from origin and destination IDs
    LatLng? startLatLng = getLatLongFromStopID(leg.originID);
    LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

    // NEXT STEPS TODO: Get these walking lines working and see if I can fix the straight-line bus segment problem (where it says ERROR: Line segment is null!)

    if (startLatLng == null && legIndex > 0) {
      // Try to get end location from previous leg
      final prevLeg = journey.legs[legIndex - 1];
      startLatLng = getLatLongFromStopID(prevLeg.destinationID);
    }

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
      color: (context != null)
          ? getColor(context!, ColorType.mapWalkingLine)
          : Colors.black, // Walk line color
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
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
  }

  void addRouteEndMarker(LatLng position, Journey journey) {
    markers.add(
      Marker(
        flat: true,
        markerId: MarkerId('journey_final_destination_${journey.hashCode}'),
        position: position,
        icon:
            _destination ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void setJourney(Journey journey, Color walkLineColor) {
    // Don't stop believin'

    // clear previous journey overlay
    polylines.clear();
    markers.clear();
    activeJourneyBusIds.clear();
    activeJourneyRoutes.clear();

    final allPoints = <LatLng>[];

    // First, analyze the journey to find which legs are bus and which are walking

    for (int legIndex = 0; legIndex < journey.legs.length; legIndex++) {
      final leg = journey.legs[legIndex];

      if (leg.destinationID == "VIRTUAL_DESTINATION" &&
          leg.pathCoords != null &&
          leg.pathCoords!.isNotEmpty) {
        addRouteEndMarker(leg.pathCoords!.last, journey);
      }

      // Determine if this is a walking or bus leg - walking legs don't have rt or trip
      final bool isBusLeg = leg.rt != null && leg.trip != null;
      // Determine leg type for processing

      if (isBusLeg) {
        addBusLegMarkersAndPolylines(leg, journey, legIndex);
      } else {
        addWalkingLegMarkersAndPolylines(leg, journey, legIndex);
      }
    }

    if (isVisible) onUpdate(); // Tell the CompositeMapWidget to update
  }

  void clearJourney() {
    markers.clear();
    polylines.clear();
    if (isVisible) onUpdate();
  }
}
