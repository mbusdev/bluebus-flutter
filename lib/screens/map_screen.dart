import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:bluebus/globals.dart';
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:bluebus/widgets/bus_sheet.dart';
import 'package:bluebus/widgets/directions_sheet.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import 'package:bluebus/widgets/stop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_selector_modal.dart';
import '../widgets/favorites_sheet.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
import '../models/bus_stop.dart';
import '../models/journey.dart';
import '../providers/bus_provider.dart';
import '../services/route_color_service.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(42.276463, -83.7374598);

  Set<Polyline> _displayedPolylines = {};
  Set<Marker> _displayedStopMarkers = {};
  Set<Marker> _displayedBusMarkers = {};
  // Journey overlays for search results
  Set<Polyline> _displayedJourneyPolylines = {};
  Set<Marker> _displayedJourneyMarkers = {};
  // Buses relevant to the active journey (when overlay active)
  Set<Marker> _displayedJourneyBusMarkers = {};
  final Set<String> _selectedRoutes = <String>{};
  List<Map<String, String>> _availableRoutes = [];
  Map<String, String> _routeIdToName = {};

  // Custom marker icons
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _favStopIcon;

  // Route specific bus icons
  final Map<String, BitmapDescriptor> _routeBusIcons = {};

  // Memoization caches
  final Map<String, Polyline> _routePolylines = {};
  final Map<String, Set<Marker>> _routeStopMarkers = {};
  // Whether a journey search overlay is currently active (shows only journey path)
  bool _journeyOverlayActive = false;
  // maximum allowed distance (meters) from a stop to a candidate polyline point
  static const double _maxMatchDistanceMeters = 150.0;
  // route ids that are part of the active journey
  final Set<String> _activeJourneyRouteIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check if custom markers are loaded first
      await _loadCustomMarkers();
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      await busProvider.loadRoutes();

      // Load route specific bus icons after routes are loaded
      await _loadRouteSpecificBusIcons();

      _updateAvailableRoutes(busProvider.routes);

      // Load favorite stops from prefs before caching overlays so markers
      // are created with the correct icon state
      await _loadFavoriteStops();

      _cacheRouteOverlays(busProvider.routes);

      // Load previously selected routes
      await _loadSelectedRoutes();

      // Only update displayed routes if we have selected routes
      if (_selectedRoutes.isNotEmpty) {
        _updateDisplayedRoutes();
      }
      busProvider.loadBuses();
      busProvider.startBusUpdates();
    });
  }

  Future<void> _loadCustomMarkers() async {
    try {
      // Load and resize stop icon
      final stopBytes = await rootBundle.load('assets/bus_stop.png');
      final stopCodec = await ui.instantiateImageCodec(
        stopBytes.buffer.asUint8List(),
        targetWidth: 70,
        targetHeight: 70,
      );
      final stopFrame = await stopCodec.getNextFrame();
      final stopData = await stopFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      _stopIcon = BitmapDescriptor.fromBytes(stopData!.buffer.asUint8List());

      // Load favorite stop icon
      try {
        final favBytes = await rootBundle.load('assets/fav_stop.png');
        final favCodec = await ui.instantiateImageCodec(
          favBytes.buffer.asUint8List(),
          targetWidth: 70,
          targetHeight: 70,
        );
        final favFrame = await favCodec.getNextFrame();
        final favData = await favFrame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (favData != null) {
          _favStopIcon = BitmapDescriptor.fromBytes(
            favData.buffer.asUint8List(),
          );
        }
      } catch (_) {
        _favStopIcon = null;
      }

      // Load route specific bus icons
      await _loadRouteSpecificBusIcons();

      // Refresh markers with new icons
      if (mounted) {
        _refreshAllMarkers();
      }
    } catch (e) {
      // Fallback to default markers if custom loading fails
      _stopIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
  }

  // Load route specific bus icons from the backend
  Future<void> _loadRouteSpecificBusIcons() async {
    try {
      if (!RouteColorService.isInitialized) {
        await RouteColorService.initialize();
      }
      final routeIds = RouteColorService.definedRouteIds;

      for (final routeId in routeIds) {
        final imageUrl = RouteColorService.getRouteImageUrl(routeId);
        if (imageUrl != null) {
          await _loadRouteBusIcon(routeId, imageUrl);
        } else {
          _setFallbackBusIcon(routeId);
        }
      }
    } catch (e) {
      // Fallback to default bus icon
      _busIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueYellow,
      );
    }
  }

  // Load a specific route's bus icon
  Future<void> _loadRouteBusIcon(String routeId, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;

        // Adjust bus icon size here
        try {
          final codec = await ui.instantiateImageCodec(
            imageBytes,
            targetWidth: 125,
            targetHeight: 125,
          );
          final frame = await codec.getNextFrame();
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );

          if (data != null) {
            _routeBusIcons[routeId] = BitmapDescriptor.fromBytes(
              data.buffer.asUint8List(),
            );
          } else {
            _setFallbackBusIcon(routeId);
          }
        } catch (codecError) {
          _setFallbackBusIcon(routeId);
        }
      } else {
        // Set fallback icon for this route
        _setFallbackBusIcon(routeId);
      }
    } catch (e) {
      // Set fallback icon for this route
      _setFallbackBusIcon(routeId);
    }
  }

  // Set a fallback bus icon for a route
  void _setFallbackBusIcon(String routeId) {
    try {
      final routeColor = RouteColorService.getRouteColor(routeId);
      _routeBusIcons[routeId] = BitmapDescriptor.defaultMarkerWithHue(
        _colorToHue(routeColor),
      );
    } catch (e) {
      // error handling
    }
  }

  // In memory cache of favorited stop ids for quick lookup and immediate UI updates
  final Set<String> _favoriteStops = <String>{};

  Future<void> _loadFavoriteStops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('favorite_stops') ?? <String>[];
      _favoriteStops.clear();
      _favoriteStops.addAll(list);
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    Provider.of<BusProvider>(context, listen: false).stopBusUpdates();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateAvailableRoutes(List<BusRouteLine> routes) {
    final Map<String, String> routeIdToName = {};
    for (final r in routes) {
      if (!routeIdToName.containsKey(r.routeId)) {
        // Use backend route name if available, otherwise fallback to local names
        final name = RouteColorService.getRouteName(r.routeId);
        routeIdToName[r.routeId] = name;

        // Load bus icon for this route if not already loaded
        if (!_routeBusIcons.containsKey(r.routeId)) {
          final imageUrl = RouteColorService.getRouteImageUrl(r.routeId);
          if (imageUrl != null) {
            _loadRouteBusIcon(r.routeId, imageUrl);
          }
        }
      }
    }
    setState(() {
      _routeIdToName = routeIdToName;
      _availableRoutes = routeIdToName.entries
          .map((e) => {'id': e.key, 'name': e.value})
          .toList();
      globalAvailableRoutes = _availableRoutes;
    });
  }

  void _cacheRouteOverlays(List<BusRouteLine> routes) {
    for (final r in routes) {
      // Create unique key for each route variant
      final routeKey = '${r.routeId}_${r.points.hashCode}';
      // Use backend color if available, otherwise fallback to service
      final routeColor = r.color ?? RouteColorService.getRouteColor(r.routeId);

      if (!_routePolylines.containsKey(routeKey)) {
        _routePolylines[routeKey] = Polyline(
          polylineId: PolylineId(routeKey),
          points: r.points,
          color: routeColor,
          width: 4,
        );
      }
      if (!_routeStopMarkers.containsKey(routeKey)) {
        _routeStopMarkers[routeKey] = r.stops
            .map(
              (stop) => Marker(
                markerId: MarkerId('stop_${stop.id}_${r.points.hashCode}'),
                position: stop.location,
                icon: _favoriteStops.contains(stop.id)
                    ? (_favStopIcon ??
                          _stopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ))
                    : (_stopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          )),
                consumeTapEvents: true,
                onTap: () {
                  _showStopSheet(
                    stop.id,
                    stop.name,
                    stop.location.latitude,
                    stop.location.longitude,
                  );
                },
              ),
            )
            .toSet();
      }
    }
  }

  // When a stop marker is tapped, show a bottom sheet to add/remove favorite
  void _onStopTapped(BusStop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _addFavoriteStop(stop.id, stop.name);
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Add to favorites'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addFavoriteStop(String stpid, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_stops') ?? <String>[];
    if (!list.contains(stpid)) {
      list.add(stpid);
      await prefs.setStringList('favorite_stops', list);
      // update in memory cache and marker icons
      setState(() {
        _favoriteStops.add(stpid);
      });
      _setStopFavorited(stpid, true);
    } else {}
  }

  Future<void> _removeFavoriteStop(String stpid, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_stops') ?? <String>[];
    if (list.contains(stpid)) {
      list.remove(stpid);
      await prefs.setStringList('favorite_stops', list);
      // update in memory cache and marker icons
      setState(() {
        _favoriteStops.remove(stpid);
      });
      _setStopFavorited(stpid, false);
    }
  }

  // Update cached markers for a specific stop id to reflect favorite/unfavorite
  void _setStopFavorited(String stpid, bool favored) {
    // Update all routeStopMarkers entries that match this stop id
    _routeStopMarkers.forEach((routeKey, markers) {
      final updated = markers.map((m) {
        if (m.markerId.value.startsWith('stop_${stpid}_')) {
          return Marker(
            markerId: m.markerId,
            position: m.position,
            icon: favored
                ? (_favStopIcon ??
                      _stopIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ))
                : (_stopIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      )),
            consumeTapEvents: m.consumeTapEvents,
            onTap: m.onTap,
            rotation: m.rotation,
            anchor: m.anchor,
          );
        }
        return m;
      }).toSet();
      _routeStopMarkers[routeKey] = updated;
    });

    // If displayed, update displayed markers as well
    setState(() {
      // Rebuild displayed stop markers based on current selected routes
      final selectedStopMarkers = <Marker>{};
      for (final routeId in _selectedRoutes) {
        final routeVariants = _routePolylines.keys.where(
          (key) => key.startsWith('${routeId}_'),
        );
        for (final routeKey in routeVariants) {
          final stops = _routeStopMarkers[routeKey];
          if (stops != null) selectedStopMarkers.addAll(stops);
        }
      }
      _displayedStopMarkers = selectedStopMarkers;
    });
  }

  bool _isFavorited(String stpid) => _favoriteStops.contains(stpid);

  void _updateDisplayedRoutes() {
    final selectedPolylines = <Polyline>{};
    final selectedStopMarkers = <Marker>{};

    for (final routeId in _selectedRoutes) {
      // Find all variants of this route
      final routeVariants = _routePolylines.keys.where(
        (key) => key.startsWith('${routeId}_'),
      );

      for (final routeKey in routeVariants) {
        final polyline = _routePolylines[routeKey];
        if (polyline != null) selectedPolylines.add(polyline);
        final stops = _routeStopMarkers[routeKey];
        if (stops != null) {
          selectedStopMarkers.addAll(stops);
        }
      }
    }

    setState(() {
      _displayedPolylines = selectedPolylines;
      _displayedStopMarkers = selectedStopMarkers;
    });
    _updateDisplayedBuses(
      Provider.of<BusProvider>(context, listen: false).buses,
    );
  }

  void _updateDisplayedBuses(List<Bus> allBuses) {
    final selectedBusMarkers = allBuses
        .where((bus) => _selectedRoutes.contains(bus.routeId))
        .map((bus) {
          // Use backend color if available, otherwise fallback to service
          final routeColor =
              bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);

          // Use route specific bus icon if available, otherwise fallback to default
          BitmapDescriptor? busIcon;
          if (_routeBusIcons.containsKey(bus.routeId)) {
            busIcon = _routeBusIcons[bus.routeId];
          } else if (_busIcon != null) {
            busIcon = _busIcon;
          } else {
            busIcon = BitmapDescriptor.defaultMarkerWithHue(
              _colorToHue(routeColor),
            );
          }

          return Marker(
            markerId: MarkerId('bus_${bus.id}'),
            consumeTapEvents: true,
            position: bus.position,
            icon: busIcon!,
            rotation: bus.heading,
            anchor: const Offset(0.5, 0.5), // Center the icon on the position
            onTap: () {
              _showBusSheet(bus.id);
            },
          );
        })
        .toSet();
    setState(() {
      _displayedBusMarkers = selectedBusMarkers;
    });
  }

  /// Convert a Color to a BitmapDescriptor hue value
  double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  void _refreshAllMarkers() {
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    _refreshCachedStopMarkers();
    _refreshRouteBusIcons();
    _updateDisplayedRoutes();
    _updateDisplayedBuses(busProvider.buses);
  }

  // Refresh route specific bus icons
  void _refreshRouteBusIcons() {
    _routeBusIcons.clear();
    _loadRouteSpecificBusIcons();
  }

  // Force refresh route specific bus icons
  Future<void> _forceRefreshRouteBusIcons() async {
    _routeBusIcons.clear();
    await _loadRouteSpecificBusIcons();
  }

  // Check if a route has specific bus icon loaded
  bool hasRouteBusIcon(String routeId) {
    return _routeBusIcons.containsKey(routeId);
  }

  // Get the number of route bus icons loaded
  int get loadedBusIconCount => _routeBusIcons.length;

  // Save selected routes to persistent storage
  Future<void> _saveSelectedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_routes', _selectedRoutes.toList());
  }

  // Load selected routes from persistent storage
  Future<void> _loadSelectedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoutes = prefs.getStringList('selected_routes') ?? [];
    setState(() {
      _selectedRoutes.addAll(savedRoutes);
    });
  }

  // Clear saved routes
  // Currently only used for testing purposes
  // Future<void> _clearSavedRoutes() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove('selected_routes');
  //   setState(() {
  //     _selectedRoutes.clear();
  //   });
  //   _updateDisplayedRoutes();
  // }

  void _refreshCachedStopMarkers() {
    // Clear cached stop markers so they'll be recreated with the new icons
    _routeStopMarkers.clear();
    // Re-cache all route overlays with the new icons
    _cacheRouteOverlays(
      Provider.of<BusProvider>(context, listen: false).routes,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // Create a bus marker from a Bus model
  Marker _createBusMarker(Bus bus) {
    final routeColor =
        bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);
    final icon =
        _routeBusIcons[bus.routeId] ??
        _busIcon ??
        BitmapDescriptor.defaultMarkerWithHue(_colorToHue(routeColor));
    return Marker(
      markerId: MarkerId('bus_${bus.id}'),
      consumeTapEvents: true,
      position: bus.position,
      icon: icon,
      rotation: bus.heading,
      anchor: const Offset(0.5, 0.5),
      onTap: () => _showBusSheet(bus.id),
    );
  }

  void _showBusRoutesModal(List<BusRouteLine> allRouteLines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return RouteSelectorModal(
          availableRoutes: _availableRoutes,
          initialSelectedRoutes: _selectedRoutes,
          onApply: (Set<String> newSelection) async {
            if (newSelection.difference(_selectedRoutes).isNotEmpty ||
                _selectedRoutes.difference(newSelection).isNotEmpty) {
              setState(() {
                _selectedRoutes.clear();
                _selectedRoutes.addAll(newSelection);
              });
              _updateDisplayedRoutes();

              // Save the new selection
              await _saveSelectedRoutes();
            }
          },
        );
      },
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SearchSheet(
          onSearch: (Location location, bool isBusStop, String stopID) {
            final searchCoordinates = location.latlng;

            // null-proofing
            if (searchCoordinates != null) {
              if (isBusStop) {
                _centerOnLocation(
                  false,
                  searchCoordinates.latitude,
                  searchCoordinates.longitude,
                );
                _showStopSheet(
                  stopID,
                  location.name,
                  searchCoordinates.latitude,
                  searchCoordinates.longitude,
                );
              } else {
                _centerOnLocation(
                  false,
                  searchCoordinates.latitude,
                  searchCoordinates.longitude,
                );
                _showBuildingSheet(location);
              }
            } else {
              // Location has no coordinates
            }
          },
        );
      },
    );
  }

  void _showBuildingSheet(Location place) {
    showBottomSheet(
      context: context,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BuildingSheet(
          building: place,
          onGetDirections: (Location location) {
            Map<String, double>? start;
            Map<String, double>? end = {
              'lat': place.latlng!.latitude,
              'lon': place.latlng!.longitude,
            };

            _showDirectionsSheet(
              start,
              end,
              "Current Location",
              place.name,
              false,
            );
          },
        );
      },
    );
  }

  void _showDirectionsSheet(
    Map<String, double>? start,
    Map<String, double>? end,
    String startLoc,
    String endLoc,
    bool dontUseLocation,
  ) {
    showBottomSheet(
      context: context,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DirectionsSheet(
          origin: start,
          dest: end,
          useOrigin: dontUseLocation,
          originName: startLoc,
          destName: endLoc, // true = start changed, false = end changed
          onChangeSelection: (Location location, bool startChanged) {
            if (startChanged) {
              _showDirectionsSheet(
                {
                  'lat': location.latlng!.latitude,
                  'lon': location.latlng!.longitude,
                },
                end,
                location.name,
                endLoc,
                true,
              );
            } else {
              _showDirectionsSheet(
                start,
                {
                  'lat': location.latlng!.latitude,
                  'lon': location.latlng!.longitude,
                },
                startLoc,
                location.name,
                dontUseLocation,
              );
            }
          },
          onSelectJourney: (journey) {
            _displayJourneyOnMap(journey);
          },
        );
      },
    );
  }

  // Display a Journey on the map
  void _displayJourneyOnMap(Journey journey) async {
    // clear previous journey overlay
    _displayedJourneyPolylines.clear();
    _displayedJourneyMarkers.clear();

    final allPoints = <LatLng>[];

    for (int legIndex = 0; legIndex < journey.legs.length; legIndex++) {
      final leg = journey.legs[legIndex];

      _activeJourneyRouteIds.clear();
      if (leg.rt != null && leg.trip != null) {
        // Try to find a cached route polyline segment that follows streets
        final startLatLng = getLatLongFromStopID(leg.originID);
        final endLatLng = getLatLongFromStopID(leg.destinationID);

        bool usedRouteGeometry = false;
        if (startLatLng != null && endLatLng != null) {
          final routeVariants = _routePolylines.keys.where(
            (key) => key.startsWith('${leg.rt}_'),
          );

          List<LatLng>? bestSegment;
          double? bestLength;

          for (final routeKey in routeVariants) {
            final poly = _routePolylines[routeKey];
            if (poly == null) continue;
            final ptsList = poly.points;
            if (ptsList.length < 2) continue;

            final seg = _extractRouteSegment(ptsList, startLatLng, endLatLng);
            if (seg != null && seg.length >= 2) {
              // compute approximate length
              double len = 0;
              for (int i = 1; i < seg.length; i++) {
                final a = seg[i - 1];
                final b = seg[i];
                final dx = a.latitude - b.latitude;
                final dy = a.longitude - b.longitude;
                len += dx * dx + dy * dy;
              }
              if (bestSegment == null || len < bestLength!) {
                bestSegment = seg;
                bestLength = len;
              }
            }
          }

          if (bestSegment != null) {
            final polyline = Polyline(
              polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
              points: bestSegment,
              color: RouteColorService.getRouteColor(leg.rt!),
              width: 6,
            );
            _displayedJourneyPolylines.add(polyline);

            // add stop markers at endpoints of the segment (boarding/alighting)
            _displayedJourneyMarkers.addAll([
              Marker(
                markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
                position: bestSegment.first,
                icon:
                    _stopIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      _colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                    ),
              ),
              Marker(
                markerId: MarkerId(
                  'journey_stop_${leg.destinationID}_$legIndex',
                ),
                position: bestSegment.last,
                icon:
                    _stopIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      _colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                    ),
              ),
            ]);

            allPoints.addAll(bestSegment);
            usedRouteGeometry = true;
          }
        }

        if (!usedRouteGeometry) {
          // Fallback to simple path
          final pts = <LatLng>[];
          bool started = false;
          for (final st in leg.trip!.stopTimes) {
            if (st.stop == leg.originID) started = true;
            if (started) {
              final latlng = getLatLongFromStopID(st.stop);
              if (latlng != null) {
                pts.add(latlng);
                allPoints.add(latlng);
                _displayedJourneyMarkers.add(
                  Marker(
                    markerId: MarkerId('journey_stop_${st.stop}_$legIndex'),
                    position: latlng,
                    icon:
                        _stopIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          _colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                        ),
                  ),
                );
              }
            }
            if (st.stop == leg.destinationID && started) break;
          }

          if (pts.isNotEmpty) {
            final poly = Polyline(
              polylineId: PolylineId('journey_${journey.hashCode}_$legIndex'),
              points: pts,
              color: RouteColorService.getRouteColor(leg.rt!),
              width: 6,
            );
            _displayedJourneyPolylines.add(poly);
          }
        }
      }
    }

    // mark that a journey overlay is active (this will hide other route polylines)
    _journeyOverlayActive = true;
    // Build bus markers for buses matching active journey routes
    _displayedJourneyBusMarkers.clear();
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    for (final bus in busProvider.buses) {
      if (_activeJourneyRouteIds.contains(bus.routeId)) {
        _displayedJourneyBusMarkers.add(_createBusMarker(bus));
      }
    }

    setState(() {});

    // Trying to move camera to include the journey bounds
    if (_mapController != null && allPoints.isNotEmpty) {
      try {
        double south = allPoints.first.latitude;
        double north = allPoints.first.latitude;
        double west = allPoints.first.longitude;
        double east = allPoints.first.longitude;
        for (final p in allPoints) {
          south = p.latitude < south ? p.latitude : south;
          north = p.latitude > north ? p.latitude : north;
          west = p.longitude < west ? p.longitude : west;
          east = p.longitude > east ? p.longitude : east;
        }

        final bounds = LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        );

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      } catch (e) {
        // fallback to center on first point
        if (allPoints.isNotEmpty) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: allPoints.first, zoom: 15),
            ),
          );
        }
      }
    }
  }

  // Clear/hide the currently displayed journey overlays and return to normal route view
  void _clearJourneyOverlays() {
    if (!_journeyOverlayActive) return;
    _displayedJourneyPolylines.clear();
    _displayedJourneyMarkers.clear();
    _displayedJourneyBusMarkers.clear();
    _journeyOverlayActive = false;
    setState(() {});
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
    final sRes = _nearestIndexAndDistanceOnPolyline(poly, start);
    final eRes = _nearestIndexAndDistanceOnPolyline(poly, end);
    final si = sRes[0] as int;
    final ei = eRes[0] as int;
    final sDist = sRes[1] as double;
    final eDist = eRes[1] as double;

    // If either nearest point is too far from the stop, we consider this polyline not a match
    if (sDist > _maxMatchDistanceMeters || eDist > _maxMatchDistanceMeters)
      return null;

    if (si == ei) return null;

    // Ensure start < end in index space, if reversed, flip the sublist
    if (si < ei) {
      return poly.sublist(si, ei + 1);
    } else {
      final seg = poly.sublist(ei, si + 1);
      return seg.reversed.toList();
    }
  }

  void _showBusSheet(String busID) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BusSheet(
          busID: busID,
          onSelectStop: (name, id) {
            LatLng? latLong = getLatLongFromStopID(id);
            if (latLong != null) {
              _showStopSheet(id, name, latLong.latitude, latLong.longitude);
            }
          },
        );
      },
    );
  }

  void _showFavoritesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FavoritesSheet(
          onSelectStop: (name, id) {
            LatLng? latLong = getLatLongFromStopID(id);
            if (latLong != null) {
              _showStopSheet(id, name, latLong.latitude, latLong.longitude);
            }
          },
          onUnfavorite: (stpid) {
            // update in memory and marker icons immediately
            setState(() {
              _favoriteStops.remove(stpid);
            });
            _setStopFavorited(stpid, false);
          },
        );
      },
    );
  }

  void _showStopSheet(String stopID, String stopName, double lat, double long) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StopSheet(
          stopID: stopID,
          stopName: stopName,
          onFavorite: _addFavoriteStop,
          onUnFavorite: _removeFavoriteStop,
          onGetDirections: () {
            Map<String, double>? start;
            Map<String, double>? end = {'lat': lat, 'lon': long};

            _showDirectionsSheet(
              start,
              end,
              "Current Location",
              stopName,
              false,
            );
          },
        );
      },
    );
  }

  Future<void> _centerOnLocation(
    bool userLocation, [
    double lat = 0,
    double long = 0,
  ]) async {
    try {
      // Check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check and request location permissions if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // at first create a default position. User location can overwrite later if needed
      Position position = Position(
        longitude: long,
        latitude: lat,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      if (userLocation) {
        position = await Geolocator.getCurrentPosition().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            throw Exception("Location request timed out.");
          },
        );
      }

      // Animate the map camera to the user's location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: userLocation ? 15.0 : 17.0,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busProvider = Provider.of<BusProvider>(context);
    if (busProvider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (busProvider.error != null) {
      return Scaffold(body: Center(child: Text(busProvider.error!)));
    }
    // Only update bus markers when buses change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (busProvider.buses.isNotEmpty) {
        _updateDisplayedBuses(busProvider.buses);
      }
    });

    return Stack(
      children: [
        // underlying map layer
        MapWidget(
          initialCenter: _defaultCenter,
          polylines: _journeyOverlayActive
              ? _displayedJourneyPolylines
              : _displayedPolylines.union(_displayedJourneyPolylines),
          markers: _journeyOverlayActive
              ? _displayedJourneyMarkers.union(_displayedJourneyBusMarkers)
              : _displayedStopMarkers
                    .union(_displayedBusMarkers)
                    .union(_displayedJourneyMarkers),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: true,
        ),

        // Safe-Area (for UI)
        SafeArea(
          // buttons
          child: Column(
            children: [
              Spacer(),

              // temp row (might add settings button to it later)
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // location button
                    FloatingActionButton.small(
                      onPressed: () {
                        _centerOnLocation(true);
                      },
                      heroTag: 'location_fab',
                      backgroundColor: const ui.Color.fromARGB(
                        176,
                        255,
                        255,
                        255,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(56),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // main buttons row
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [
                    // routes
                    SizedBox(
                      width: 55,
                      height: 55,
                      child: FittedBox(
                        child: FloatingActionButton(
                          onPressed: () =>
                              _showBusRoutesModal(busProvider.routes),
                          heroTag: 'routes_fab',
                          backgroundColor: maizeBusDarkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(56),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 15),

                    // favorites
                    SizedBox(
                      width: 55,
                      height: 55,
                      child: FittedBox(
                        child: FloatingActionButton(
                          onPressed: () {
                            _showFavoritesSheet();
                          },
                          heroTag: 'favorites_fab',
                          backgroundColor: maizeBusDarkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(56),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    Spacer(),

                    // search
                    SizedBox(
                      width: 75,
                      height: 75,
                      child: FittedBox(
                        child: FloatingActionButton(
                          onPressed: () => _showSearchSheet(),
                          heroTag: 'search_fab',
                          backgroundColor: maizeBusDarkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(56),
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // clear journey overlay button (only visible when an overlay is active)
                    if (_journeyOverlayActive)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FittedBox(
                          child: FloatingActionButton.small(
                            onPressed: _clearJourneyOverlays,
                            heroTag: 'clear_journey_fab',
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.clear,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
