import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
import 'package:haptic_feedback/haptic_feedback.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_selector_modal.dart';
import '../widgets/favorites_sheet.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
//import '../models/bus_stop.dart';
import '../models/journey.dart';
import '../providers/bus_provider.dart';
import '../services/route_color_service.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
//import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late bool canVibrate;

  Future<void>? _dataLoadingFuture;
  final _loadingMessageNotifier = ValueNotifier<String>('Initializing...');

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
  // Search location marker (red pin when viewing building/stop details)
  Marker? _searchLocationMarker;
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
  final Set<String> _activeJourneyBusIds = {};
  // route ids of routes used in the active journey
  final Set<String> _activeJourneyRoutes = {};
  // cache last directions request origin/dest coordinates (used for VIRTUAL_* stops)
  Map<String, double>? _lastJourneyRequestOrigin;
  Map<String, double>? _lastJourneyRequestDest;

  // this function is to load all the data on app launch and
  // still keep context
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataLoadingFuture == null) {
      _dataLoadingFuture = _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    canVibrate = await Haptics.canVibrate();

    final busProvider = Provider.of<BusProvider>(context, listen: false);

    _loadingMessageNotifier.value = 'Contacting server...';
    StartupDataHolder? startupData = await _getBackendMinVersion();

    // keep trying to reach server. Can't start without this
    while (startupData == null) {
      _loadingMessageNotifier.value = "Unable to connect";
      await Future.delayed(Duration(seconds: 2));
      startupData = await _getBackendMinVersion();
    }

    if (!isCurrentVersionEqualOrHigher(startupData.version)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              startupData!.updateTitle,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            content: Text(
              startupData!.updateMessage,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          );
        },
      );
    }

    // loading all this data in parallel
    await Future.wait([
      _loadCustomMarkers(),
      busProvider.loadRoutes(),
      _loadSelectedRoutes(),
      _loadFavoriteStops(),
    ]);

    // actions that depend on the data loaded earlier
    _loadingMessageNotifier.value = 'Loading bus images...';
    await _loadRouteSpecificBusIcons();
    _updateAvailableRoutes(busProvider.routes);
    _cacheRouteOverlays(busProvider.routes);

    // update the map with previously selected routes.
    if (_selectedRoutes.isNotEmpty) {
      _updateDisplayedRoutes();
    }

    // Finally, get the initial bus locations and start the live updates.
    _loadingMessageNotifier.value = 'Loading bus positions...';
    await busProvider.loadBuses();

    _loadingMessageNotifier.value = 'Loading bus stops...';
    _loadStopsForLaunch();

    _loadingMessageNotifier.value = 'Starting app...';
    busProvider.startBusUpdates();
  }

  // need this to make sure that the stop names exist in the cache
  Future<void> _loadStopsForLaunch() async {
    final stopResponse = await http.get(
      Uri.parse(BACKEND_URL + '/getAllStops'),
    );
    List<Location> stopLocs = [];
    if (stopResponse.statusCode == 200 &&
        stopResponse.body.trim().isNotEmpty &&
        stopResponse.body.trim() != '{}') {
      final stopList = jsonDecode(stopResponse.body) as List<dynamic>;
      stopLocs = stopList.map((stop) {
        final name = stop['name'] as String;
        final aliases = [
          name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join(),
        ];
        final stopId = stop['stpid'] as String?;
        final lat = stop['lat'] as double?;
        final lon = stop['lon'] as double?;
        return Location(
          name,
          (stopId != null) ? stopId : "",
          aliases,
          true,
          stopId: stopId,
          latlng: (lat != null && lon != null) ? LatLng(lat, lon) : null,
        );
      }).toList();
    }
    globalStopLocs = stopLocs;
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

      // Check if we need to update cached assets based on version
      final shouldRefreshAssets = await _shouldRefreshCachedAssets();

      final routeIds = RouteColorService.definedRouteIds;

      for (final routeId in routeIds) {
        // Try to load from cache first if not forcing refresh
        if (!shouldRefreshAssets) {
          final cachedIcon = await _loadCachedBusIcon(routeId);
          if (cachedIcon != null) {
            _routeBusIcons[routeId] = cachedIcon;
            continue;
          }
        }

        // Load from backend if cache miss or forcing refresh
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

  Future<int> getFrontEndImageVer() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int counter = prefs.getInt('imageVer') ?? 0;

    // if null, save the default value
    if (prefs.getInt('imageVer') == null) {
      await prefs.setInt('imageVer', counter);
    }

    return counter;
  }

  Future<void> setFrontEndImageVer(int a) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('imageVer', a);
  }

  // Check if cached assets need to be refreshed based on backend version
  Future<bool> _shouldRefreshCachedAssets() async {
    int frontEndVer;
    frontEndVer = await getFrontEndImageVer();

    try {
      final backendImageVersion = await _getBackendImageVersion();
      if (backendImageVersion == null) {
        return true; // if you can't reach the server give up
      }
      if (int.parse(backendImageVersion) == frontEndVer) {
        return false;
      } else {
        await setFrontEndImageVer(int.parse(backendImageVersion));
        return true;
      }
    } catch (e) {
      // On error, assume refresh needed
      return true;
    }
  }

  // Get minimum supported version from backend
  Future<StartupDataHolder?> _getBackendMinVersion() async {
    try {
      final response = await http.get(Uri.parse('$BACKEND_URL/getStartupInfo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['why_update_message'];
        return StartupDataHolder(
          data['min_supported_version'],
          message['title'],
          message['subtitle'],
        );
      }
    } catch (e) {
      return null;
    }
  }

  // Get minimum supported version from backend
  Future<String?> _getBackendImageVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${BACKEND_URL}/getStartupInfo'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['bus_image_version'] as String?;
      }
    } catch (e) {
      // Return null on error - will trigger refresh
    }
    return null;
  }

  // Load cached bus icon from SharedPreferences
  Future<BitmapDescriptor?> _loadCachedBusIcon(String routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBytes = prefs.getString('bus_icon_$routeId');
      if (cachedBytes != null) {
        final bytes = base64.decode(cachedBytes);
        return BitmapDescriptor.fromBytes(bytes);
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  // Save bus icon to cache
  Future<void> _cacheBusIcon(String routeId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = base64.encode(bytes);
      await prefs.setString('bus_icon_$routeId', base64String);
    } catch (e) {
      // Ignore cache save errors
    }
  }

  // // Clear all cached bus icons and version info (useful for development/testing)
  // Future<void> _clearIconCache() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final keys = prefs.getKeys();

  //     for (final key in keys) {
  //       if (key.startsWith('bus_icon_') || key == 'cached_assets_version') {
  //         await prefs.remove(key);
  //       }
  //     }

  //     // Clear in-memory cache too
  //     _routeBusIcons.clear();
  //   } catch (e) {
  //     // Ignore errors
  //   }
  // }

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
            final processedBytes = data.buffer.asUint8List();
            _routeBusIcons[routeId] = BitmapDescriptor.fromBytes(
              processedBytes,
            );

            // Cache the processed icon for future use
            await _cacheBusIcon(routeId, processedBytes);
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
    _loadingMessageNotifier.dispose();
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
    // null case or error contacting server case
    if (allBuses == []) return;

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

    // Update journey bus markers if journey is active
    if (_journeyOverlayActive && _activeJourneyRoutes.isNotEmpty) {
      _displayedJourneyBusMarkers.clear();
      for (final bus in allBuses) {
        // Show buses that are on routes used in the journey
        if (_activeJourneyRoutes.contains(bus.routeId)) {
          final routeColor =
              bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);
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

          _displayedJourneyBusMarkers.add(
            Marker(
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

    setState(() {
      _displayedBusMarkers = selectedBusMarkers;
    });
  }

  /// Convert a Color to a BitmapDescriptor hue value
  double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  // Show a red pin marker at search location
  void _showSearchLocationMarker(double lat, double lon) {
    _searchLocationMarker = Marker(
      markerId: const MarkerId('search_location'),
      position: LatLng(lat, lon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      consumeTapEvents: false,
    );
    setState(() {});
  }

  // Remove the search location marker
  void _removeSearchLocationMarker() {
    _searchLocationMarker = null;
    setState(() {});
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
          canVibrate: canVibrate,
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

            // Clear any existing search location marker first
            _removeSearchLocationMarker();

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
    // Show red pin at the location
    _showSearchLocationMarker(place.latlng!.latitude, place.latlng!.longitude);

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
            // Clear any existing search location marker before showing new destination
            _removeSearchLocationMarker();

            if (startChanged) {
              // Show red pin for new start location if it's a building (not bus stop)
              if (!location.isBusStop) {
                _showSearchLocationMarker(
                  location.latlng!.latitude,
                  location.latlng!.longitude,
                );
              }

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
              // Show red pin for new destination if it's a building (non-bus stop)
              if (!location.isBusStop) {
                _showSearchLocationMarker(
                  location.latlng!.latitude,
                  location.latlng!.longitude,
                );
              }

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
          onResolved: (orig, dest) {
            // Cache resolved coordinates for virtual origin/destination resolution
            _lastJourneyRequestOrigin = orig;
            _lastJourneyRequestDest = dest;
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
    _activeJourneyBusIds.clear();
    _activeJourneyRoutes.clear();

    final allPoints = <LatLng>[];

    // First, analyze the journey to find which legs are bus and which are walking

    for (int legIndex = 0; legIndex < journey.legs.length; legIndex++) {
      final leg = journey.legs[legIndex];

      // Determine if this is a walking or bus leg - walking legs don't have rt or trip
      final bool isBusLeg = leg.rt != null && leg.trip != null;
      // Determine leg type for processing

      if (isBusLeg) {
        // Add route ID and vehicle ID to active sets for bus filtering
        if (leg.rt != null) {
          _activeJourneyRoutes.add(leg.rt!);
        }
        if (leg.trip != null) {
          _activeJourneyBusIds.add(leg.trip!.vid);
        } // Try to find a cached route polyline segment that follows streets
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
      } else {
        // Walking legs add a dotted line between origin and destination
        // First try to get the locations from origin and destination IDs
        LatLng? startLatLng = getLatLongFromStopID(leg.originID);
        LatLng? endLatLng = getLatLongFromStopID(leg.destinationID);

        // Walking leg information

        // Locations were not found, could be a building or custom location
        // In this case, we need to look for coordinates in previous/next legs
        // Also handle virtual origin/destination from the directions request
        if (startLatLng == null) {
          // resolve virtual origin
          if (leg.originID == 'VIRTUAL_ORIGIN' &&
              _lastJourneyRequestOrigin != null) {
            startLatLng = LatLng(
              _lastJourneyRequestOrigin!['lat']!,
              _lastJourneyRequestOrigin!['lon']!,
            );
          } else if (leg.originID == 'VIRTUAL_DESTINATION' &&
              _lastJourneyRequestDest != null) {
            startLatLng = LatLng(
              _lastJourneyRequestDest!['lat']!,
              _lastJourneyRequestDest!['lon']!,
            );
          }
        }

        // If still unresolved and this is a virtual origin, attempt to use device location
        if (startLatLng == null && leg.originID == 'VIRTUAL_ORIGIN') {
          try {
            final pos = await Geolocator.getCurrentPosition().timeout(
              Duration(seconds: 3),
            );
            startLatLng = LatLng(pos.latitude, pos.longitude);
          } catch (e) {
            // ignore GPS resolution failure
          }
        }

        if (startLatLng == null && legIndex > 0) {
          // Try to get end location from previous leg
          final prevLeg = journey.legs[legIndex - 1];
          startLatLng = getLatLongFromStopID(prevLeg.destinationID);
        }

        if (endLatLng == null) {
          // resolve virtual destination
          if (leg.destinationID == 'VIRTUAL_DESTINATION' &&
              _lastJourneyRequestDest != null) {
            endLatLng = LatLng(
              _lastJourneyRequestDest!['lat']!,
              _lastJourneyRequestDest!['lon']!,
            );
          } else if (leg.destinationID == 'VIRTUAL_ORIGIN' &&
              _lastJourneyRequestOrigin != null) {
            endLatLng = LatLng(
              _lastJourneyRequestOrigin!['lat']!,
              _lastJourneyRequestOrigin!['lon']!,
            );
          }
        }

        // If still unresolved and this is a virtual destination, attempt device location fallback
        if (endLatLng == null && leg.destinationID == 'VIRTUAL_DESTINATION') {
          try {
            final pos = await Geolocator.getCurrentPosition().timeout(
              Duration(seconds: 3),
            );
            endLatLng = LatLng(pos.latitude, pos.longitude);
          } catch (e) {
            print('Could not resolve VIRTUAL_DESTINATION via device GPS: $e');
          }
        }

        if (endLatLng == null && legIndex < journey.legs.length - 1) {
          // Try to get start location from next leg
          final nextLeg = journey.legs[legIndex + 1];
          endLatLng = getLatLongFromStopID(nextLeg.originID);
        }

        // Check if we have both coordinates before creating walking polyline
        if (startLatLng != null && endLatLng != null) {
          // Create a dotted line for walking segments
          final walkingPolyline = Polyline(
            polylineId: PolylineId('walking_${journey.hashCode}_$legIndex'),
            points: [startLatLng, endLatLng],
            color: Colors.black, // Walk line color
            width: 6, // lind width
            patterns: [
              PatternItem.dash(30), // Longer dashes
              PatternItem.gap(15), // Longer gaps
            ],
          );

          _displayedJourneyPolylines.add(walkingPolyline);
          allPoints.addAll([startLatLng, endLatLng]);

          // Only add destination marker if this is the final leg of the journey
          if (legIndex == journey.legs.length - 1) {
            _displayedJourneyMarkers.add(
              Marker(
                markerId: MarkerId(
                  'journey_final_destination_${journey.hashCode}',
                ),
                position: endLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            );
          }

          // Add starting marker if this is the first leg of the journey
          if (legIndex == 0) {
            _displayedJourneyMarkers.add(
              Marker(
                markerId: MarkerId('journey_start_${journey.hashCode}'),
                position: startLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            );
          } // doing this for now bc couldnt figure out marker stuff better
        }
      }
    }

    // mark that a journey overlay is active (this will hide other route polylines)
    _journeyOverlayActive = true;

    // Build bus markers for buses matching active journey routes
    // Filter by route first, then optionally by specific vehicle ID if available
    _displayedJourneyBusMarkers.clear();
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    for (final bus in busProvider.buses) {
      // Show buses that are on routes used in the journey
      if (_activeJourneyRoutes.contains(bus.routeId)) {
        _displayedJourneyBusMarkers.add(_createBusMarker(bus));
      }
    }

    // Final debug check
    // Journey display complete (silently updated internal state)

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

        // Adjust bounds to position route in top 1/3 of screen (accounting for bottom sheet)
        final latSpan = north - south;
        final adjustedSouth =
            south - (latSpan * 0.8); // Much more padding to bottom
        final adjustedNorth = north + (latSpan * 0.2); // Less padding to top

        final bounds = LatLngBounds(
          southwest: LatLng(adjustedSouth, west),
          northeast: LatLng(adjustedNorth, east),
        );

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      } catch (e) {
        // fallback to center on first point higher up
        if (allPoints.isNotEmpty) {
          // Calculate center of route points
          double centerLat = 0;
          double centerLon = 0;
          for (final p in allPoints) {
            centerLat += p.latitude;
            centerLon += p.longitude;
          }
          centerLat /= allPoints.length;
          centerLon /= allPoints.length;

          // Offset the center significantly north to place in top 1/3
          final offsetLat = centerLat + 0.008; // Roughly 800m north

          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(offsetLat, centerLon), zoom: 13),
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
    _activeJourneyBusIds.clear();
    _activeJourneyRoutes.clear();
    _journeyOverlayActive = false;
    // making sure to remove search location marker when clearing journey
    _removeSearchLocationMarker();
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
            } else {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Error'),
                    content: const Text('Couldn\'t load stop.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Dismiss the dialog
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
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
            } else {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Error'),
                    content: const Text('Couldn\'t load stop.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Dismiss the dialog
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
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
    ).then((_) {});
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
            content: Text('Location permissions are denied. Please enable them in settings'),
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
    // Only update bus markers when buses change
    final busProvider = Provider.of<BusProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (busProvider.buses.isNotEmpty) {
        _updateDisplayedBuses(busProvider.buses);
      }
    });

    return FutureBuilder(
      future: _dataLoadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            children: [
              // underlying map layer
              MapWidget(
                initialCenter: _defaultCenter,
                polylines: _journeyOverlayActive
                    ? _displayedJourneyPolylines
                    : _displayedPolylines.union(_displayedJourneyPolylines),
                markers: _journeyOverlayActive
                    ? _displayedJourneyMarkers
                          .union(_displayedJourneyBusMarkers)
                          .union(
                            _searchLocationMarker != null
                                ? {_searchLocationMarker!}
                                : {},
                          )
                    : _displayedStopMarkers
                          .union(_displayedBusMarkers)
                          .union(_displayedJourneyMarkers)
                          .union(
                            _searchLocationMarker != null
                                ? {_searchLocationMarker!}
                                : {},
                          ),
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
                    // if showing journey, show header
                    (_journeyOverlayActive)
                        ? Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ui.Color.fromARGB(39, 0, 0, 0),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: Offset(
                                    0,
                                    3,
                                  ), // changes position of shadow
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 10),

                                Icon(Icons.route),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    "Showing route on map",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Urbanist',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox.shrink(),

                    Spacer(),

                    // temp row (might add settings button to it later)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 15,
                        right: 15,
                        top: 15,
                      ),
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

                    // if showing journey, show close button
                    (_journeyOverlayActive)
                        ? ElevatedButton.icon(
                            onPressed: _clearJourneyOverlays,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              elevation: 4,
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ), // The icon on the left
                            label: const Text(
                              'Close',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ), // The text on the right
                          )
                        // else, main buttons row
                        : Padding(
                            padding: const EdgeInsets.only(
                              left: 15,
                              right: 15,
                              top: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,

                              children: [
                                // routes
                                SizedBox(
                                  width: 55,
                                  height: 55,
                                  child: FittedBox(
                                    child: FloatingActionButton(
                                      onPressed: () async {
                                        if (canVibrate){
                                          await Haptics.vibrate(HapticsType.light);
                                        }
                                        _showBusRoutesModal(busProvider.routes,);
                                      },
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
                                      onPressed: () async {
                                        if (canVibrate){
                                          await Haptics.vibrate(HapticsType.light);
                                        }
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
                                      onPressed: () async {
                                        if (canVibrate){
                                          await Haptics.vibrate(HapticsType.light);
                                        }
                                        _showSearchSheet();
                                      },
                                      heroTag: 'search_fab',
                                      backgroundColor: maizeBusDarkBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(56),
                                      ),
                                      child: const Icon(
                                        Icons.search_sharp,
                                        size: 35,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                    SizedBox(
                      height: (MediaQuery.of(context).padding.bottom == 0.0)
                          ? 10
                          : 0,
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // LOADING SCREEN
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 30),

                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const ui.Color.fromARGB(255, 228, 228, 228),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: Offset(0, 5), // changes position of shadow
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage('assets/appicon.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                SizedBox(width: 30),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Loading",
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: const ui.Color.fromARGB(255, 11, 83, 148),
                            ),
                          ),

                          SizedBox(width: 10),

                          ValueListenableBuilder<String>(
                            valueListenable: _loadingMessageNotifier,
                            builder: (context, message, child) {
                              return Text(
                                message,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Urbanist',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 18,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
