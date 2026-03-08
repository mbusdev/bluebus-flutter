import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:bluebus/globals.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:bluebus/widgets/bus_sheet.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/directions_sheet.dart';
import 'package:bluebus/widgets/journey_results_widget.dart';
import 'package:bluebus/widgets/loading_screen.dart';
import 'package:bluebus/widgets/reminder_widgets.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import 'package:bluebus/widgets/stop_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_selector_modal.dart';
import '../widgets/favorites_sheet.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
//import '../models/bus_stop.dart';
import '../models/journey.dart';
import '../providers/bus_provider.dart';
import '../services/route_color_service.dart';
import '../constants.dart';
import './settings.dart';
//import 'dart:convert';

// Function to calculate rotation angle between two geographical points
// (used for bus stop icon orientation)
double pointRotation(double lat1, double lon1, double lat2, double lon2) {
  const double degToRad = 0.017453292519943295; // π / 180
  const double radToDeg = 57.29577951308232;    // 180 / π

  double dLat = lat2 - lat1;
  double dLon = lon2 - lon1;

  // Scale longitude by cos(lat) to correct for east-west distance
  double x = dLon * (Math.cos(lat1 * degToRad));
  double y = dLat;

  double angle = Math.atan2(x, y) * radToDeg;

  // Normalize to [0, 360)
  if (angle < 0) angle += 360;

  return angle;
}

Future<BitmapDescriptor> resizeImage(ByteData image) async {
  // Load and resize stop icon
  final stopBytes = image;
  final stopCodec = await ui.instantiateImageCodec(
    stopBytes.buffer.asUint8List(),
    // targetWidth: 65,
    // targetHeight: 65,
    targetWidth: 40,
    targetHeight: 40
  );
  final stopFrame = await stopCodec.getNextFrame();
  final stopData = await stopFrame.image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return BitmapDescriptor.fromBytes(stopData!.buffer.asUint8List());

}

class MaizeBusCore extends StatefulWidget {
  const MaizeBusCore({super.key});

  @override
  State<MaizeBusCore> createState() => _MaizeBusCoreState();
}

class _MaizeBusCoreState extends State<MaizeBusCore> {
  late bool canVibrate;
  late Journey currDisplayed;

  Future<void>? _dataLoadingFuture;
  final _loadingMessageNotifier = ValueNotifier<Loadpoint>(Loadpoint("Initializing...", 0));
  GoogleMapController? _mapController;
  CameraPosition? _currentCameraPos;
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

  Set<Marker> _allDisplayedStopMarkers = {};
  // Union of _displayedStopMarkers, _displayedBusMarkers, _displayedJourneyMarkers,
  //     and _searchLocationMarker. Stored here so build() has better performance

  Marker? _searchLocationMarker;
  final Set<String> _selectedRoutes = <String>{};
  List<Map<String, String>> _availableRoutes = [];

  // Custom marker icons
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _rideStopIcon;
  BitmapDescriptor? _favStopIcon;
  BitmapDescriptor? _favRideStopIcon;
  BitmapDescriptor? _getOn;
  BitmapDescriptor? _getOff;

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  // store persistent bottom sheet controller
  PersistentBottomSheetController? _bottomSheetController;

  // GoogleMaps styles
  String _darkMapStyle = "{}";
  String _lightMapStyle = "{}";
  
  Future _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/maps_dark_style.json');
    _lightMapStyle = await rootBundle.loadString('assets/maps_light_style.json');
  }

  @override
  void initState() {
    super.initState();
    _setupConnectivityMonitoring();
  }

  Future<void> _setupConnectivityMonitoring() async {
    final connectivity = Connectivity();

    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((results) {
      final offline = _isOfflineResult(results);
      if (mounted && _isOffline != offline) {
        setState(() {
          _isOffline = offline;
        });
      }
    });

    final initial = await connectivity.checkConnectivity();
    final initialOffline = _isOfflineResult(initial);
    if (mounted && _isOffline != initialOffline) {
      setState(() {
        _isOffline = initialOffline;
      });
    }
  }

  bool _isOfflineResult(dynamic result) {
    final List<ConnectivityResult> results = switch (result) {
      ConnectivityResult r => [r],
      List<ConnectivityResult> r => r,
      _ => const [],
    };
    if (results.isEmpty) return true;
    return results.every((r) => r == ConnectivityResult.none);
  }

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
    

    ThemeProvider theme = Provider.of<ThemeProvider>(context, listen: false);
    theme.onSystemThemeUpdate(context);
    await theme.loadTheme(); // load user theme data

    canVibrate = await Haptics.canVibrate();
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    _loadingMessageNotifier.value = Loadpoint('Contacting server...', 1);
    StartupDataHolder? startupData = await _getStartupData();

    // keep trying to reach server. Can't start without this
    while (startupData == null) {
      await Future.delayed(Duration(seconds: 2));
      startupData = await _getStartupData();
    }

    // moving this here fixes loading bug
    await RouteColorService.initialize();

    if (!isCurrentVersionEqualOrHigher(startupData.version)) {
      showUndismissableMaizebusDialog(
        contextIn: context,
        title: Text(startupData.updateTitle),
        content: Text(startupData.updateMessage)
      );
    }

    if (startupData.persistantMessageTitle != ''){
      showMaizebusOKDialog(
        contextIn: context,
        title: Text(startupData.persistantMessageTitle),
        content: Text(startupData.persistantMessage)
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
    _loadingMessageNotifier.value = Loadpoint('Loading bus images...', 2);
    await _loadRouteSpecificBusIcons();
    _updateAvailableRoutes(busProvider.routes);
    _cacheRouteOverlays(busProvider.routes);

    // update the map with previously selected routes.
    if (_selectedRoutes.isNotEmpty) {
      _updateDisplayedRoutes();
    }

    // load GoogleMaps styles
    await _loadMapStyles();

    // Finally, get the initial bus locations and start the live updates.
    _loadingMessageNotifier.value = Loadpoint('Loading bus positions...', 3);
    await busProvider.loadBuses();

    _loadingMessageNotifier.value = Loadpoint('Loading bus stops...', 4);
    _loadStopsForLaunch();

    _loadingMessageNotifier.value = Loadpoint('Starting app...', 5);
    busProvider.startBusUpdates();
    busProvider.startRouteUpdates();
    await Future.delayed(const Duration(milliseconds: 180)); 
  }

  // need this to make sure that the stop names exist in the cache
  Future<void> _loadStopsForLaunch() async {
    // LOADS BOTH STOP TYPES
    final uriStops = Uri.parse(BACKEND_URL + '/getAllStops');
    final uriRideStops = Uri.parse(BACKEND_URL + '/getAllRideStops');

    // Calling in parallel
    final responses = await Future.wait([
      http.get(uriStops),
      http.get(uriRideStops),
    ]);

    // Helper function to parse a response into a List<Location>
    // This prevents copying/pasting the parsing logic.
    List<Location> parseLocations(http.Response response) {
      if (response.statusCode == 200 &&
          response.body.trim().isNotEmpty &&
          response.body.trim() != '{}') {
        
        final stopList = jsonDecode(response.body) as List<dynamic>;
        
        return stopList.map((stop) {
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
      return []; // Return empty list if call failed or body is empty
    }

    // parse both and merge
    List<Location> stopLocs = [
      ...parseLocations(responses[0]),
      ...parseLocations(responses[1]),
    ];

    globalStopLocs = stopLocs;
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: ui.Color.fromARGB(48, 0, 0, 0),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'No internet connection',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Urbanist',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCustomMarkers() async {
    try {
      // Load stop icons
      _stopIcon = await resizeImage(  
        await rootBundle.load('assets/busStop.png'),
      );
      _rideStopIcon = await resizeImage(
        await rootBundle.load('assets/busStopRide.png'),
      );
      _favStopIcon = await resizeImage(
        await rootBundle.load('assets/favbusStop.png'),
      );
      _favRideStopIcon = await resizeImage(
        await rootBundle.load('assets/favbusStopRide.png'),
      );
      _getOn = await resizeImage(  
        await rootBundle.load('assets/getOn.png'),
      );
      _getOff = await resizeImage(
        await rootBundle.load('assets/getOff.png'),
      );

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
  Future<StartupDataHolder?> _getStartupData() async {
    try {
      final response = await http.get(Uri.parse('$BACKEND_URL/getStartupInfo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['why_update_message'];
        final p_message = data['persistant_message'];
        return StartupDataHolder(
          data['min_supported_version'],
          message['title'],
          message['subtitle'],
          p_message['title'],
          p_message['subtitle']
        );
      }
    } catch (e) {
      return null;
    }
    return null;
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
            // targetWidth: 125,
            targetWidth: 20,
            targetHeight: 20,
            // targetHeight: 125,
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
    _connectivitySubscription?.cancel();
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
                flat: true,
                icon: _favoriteStops.contains(stop.id)
                    ? (stop.isRide? 
                        _favRideStopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ) : 
                        _favStopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ))
                    : (stop.isRide?
                        _rideStopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ) :
                        _stopIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          )),
                consumeTapEvents: true,
                onTap: () {
                  try {
                    Haptics.vibrate(HapticsType.light);
                  } catch (e) { }
                  
                  _showStopSheet(
                    stop.id,
                    stop.name,
                    stop.location.latitude,
                    stop.location.longitude,
                  );
                },
                rotation: stop.rotation,
                anchor: Offset(0.5, 0.5),
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
            flat: true,
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
      _updateAllDisplayedMarkers();
    });
  }


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
      _updateAllDisplayedMarkers();
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
            flat: true,
            markerId: MarkerId('bus_${bus.id}'),
            consumeTapEvents: true,
            position: bus.position,
            icon: busIcon!,
            rotation: bus.heading,
            anchor: const Offset(0.5, 0.5), // Center the icon on the position
            onTap: () {
              try {
                Haptics.vibrate(HapticsType.light);
              } catch (e) { }
              _showBusSheet(bus.id);
            },
          );
        })
        .toSet();

    // Update journey bus markers if journey is active
    if (_journeyOverlayActive && _activeJourneyBusIds.isNotEmpty) {
      _displayedJourneyBusMarkers.clear();
      for (final bus in allBuses) {
        // Show buses that are on routes used in the journey
        if (_activeJourneyBusIds.contains(bus.id)) {
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

    
    setState(() {
      _displayedBusMarkers = selectedBusMarkers;
      _updateAllDisplayedMarkers();
    });
  }

  void _updateAllDisplayedMarkers() {
    _allDisplayedStopMarkers = _displayedStopMarkers
      .union(_displayedBusMarkers)
      .union(_displayedJourneyMarkers)
      .union(
        _searchLocationMarker != null
            ? {_searchLocationMarker!}
            : {},
      );
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

  void _onCameraMove(CameraPosition position) async {
    _currentCameraPos = position;
    
  }

  void _onCameraIdle() async {
    // Camera idle callback - can be used for future functionality
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
      flat: true,
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

    _bottomSheetController = showBottomSheet(
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
    _bottomSheetController = showBottomSheet(
      context: context,
      enableDrag: true,
      
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, 
          maxChildSize: 0.9, 
          minChildSize: 0,  
          expand: false,
          snap: true,
          snapSizes: [0.5, 0.9],
          builder: (context, scrollController){
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
                _displayJourneyOnMap(journey, getColor(context, ColorType.opposite));
              },
              onResolved: (orig, dest) {
                // Cache resolved coordinates for virtual origin/destination resolution
                _lastJourneyRequestOrigin = orig;
                _lastJourneyRequestDest = dest;
              },
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  _showJourneySheetOnReopen(){
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0,    
          maxChildSize: 0.9,    
          snap: true,
          expand: false,        
          
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: getColor(context, ColorType.background),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                shrinkWrap: true, 
                children: [
                  Text(
                    'Steps',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 15),
                  JourneyBody(journey: currDisplayed),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Display a Journey on the map
  void _displayJourneyOnMap(Journey journey, Color walkLineColor) async {
    currDisplayed = journey;

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

            // add stop markers at endpoints of the segment (boarding/getting off)
            _displayedJourneyMarkers.addAll([
              Marker(
                flat: true,
                markerId: MarkerId('journey_stop_${leg.originID}_$legIndex'),
                position: bestSegment.first,
                icon:
                    _getOn ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      _colorToHue(RouteColorService.getRouteColor(leg.rt!)),
                    ),
              ),
              Marker(
                flat: true,
                markerId: MarkerId(
                  'journey_stop_${leg.destinationID}_$legIndex',
                ),
                position: bestSegment.last,
                icon:
                    _getOff ??
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
                    flat: true,
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

        if (endLatLng == null && legIndex < journey.legs.length - 1) {
          // Try to get start location from next leg
          final nextLeg = journey.legs[legIndex + 1];
          endLatLng = getLatLongFromStopID(nextLeg.originID);
        }

        // Check if we have both coordinates before creating walking polyline
        if (startLatLng != null && endLatLng != null) {
          List<LatLng> pts = [];
          if (leg.pathCoords != null && leg.pathCoords!.isNotEmpty) {
            pts = leg.pathCoords!;
          } else {
            pts = [startLatLng, endLatLng];
          }

          // Create a dotted line for walking segments
          final walkingPolyline = Polyline(
            polylineId: PolylineId('walking_${journey.hashCode}_$legIndex'),
            points: pts,
            color: walkLineColor, // Walk line color
            width: 6, // line width
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
                flat: true,
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
                flat: true,
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

    setState(() {
      _updateAllDisplayedMarkers();
    });

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
            south - (latSpan) * 2; // Much more padding to bottom
        final adjustedNorth = north; // Less padding to top

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
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.85,
          snap: true,

          builder: (BuildContext context, ScrollController scrollController) {
            return BusSheet(
              busID: busID,
              scrollController: scrollController,
              onSelectStop: (name, id) {
                Navigator.pop(context); // Close the current modal
                LatLng? latLong = getLatLongFromStopID(id);
                if (latLong != null) {
                  _showStopSheet(id, name, latLong.latitude, latLong.longitude);
                } else {
                  showMaizebusOKDialog(
                    contextIn: context,
                    title: const Text("Error"),
                    content: const Text("Couldn't load stop."),
                  );
                }
              },
            );
          },
        )
      )
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
              showMaizebusOKDialog(
                contextIn: context,
                title: const Text('Error'),
                content: const Text('Couldn\'t load stop.'),
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
    final busProvider = Provider.of<BusProvider>(context, listen: false);

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
          showBusSheet: (busId) {
            // When someone clicks "See all stops for this bus" this callback runs
            debugPrint("Got 'See all stops' click for Bus ${busId}");
            Navigator.pop(context); // Close the current modal
            _showBusSheet(busId);
          },
          busProvider: busProvider,
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
  
  Future<void> _centerOnLocation(double lat, double long) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, long),
            zoom: 17.0,
          ),
        ),
      );
    }
  }

  Future<void> _setMapToNorth() async {
    if (_mapController != null && _currentCameraPos != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCameraPos!.target, // current position
            zoom: _currentCameraPos!.zoom,
            bearing: 0, // face north
          )
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

    if (!globallPaddingHasBeenSet){
      // set all padding
      // first, getting all the padding values
      final mediaQueryData = MediaQuery.of(context);
      final double flutterSafeAreaTop = mediaQueryData.padding.top;
      final double flutterSafeAreaBottom = mediaQueryData.padding.bottom;
      // then, changing them based on phone
      if(Platform.isIOS){
        if(flutterSafeAreaBottom == 0){
          // rectangle iphone
          globalBottomPadding = 10;
          globalLeftRightPadding = 10;
          globalTopPadding = 20;
        } else {
          // round iphone
          globalBottomPadding = 30;
          globalLeftRightPadding = 30;
          globalTopPadding = flutterSafeAreaTop;
        }
      } else {
        // andoird
        
        if (flutterSafeAreaBottom < 30){
          // in this case, 30 from the bottom is fine because
          // it's over the safe area. this usually works
          // for round bottom phones like the google pixel

          globalBottomPadding = 30;
          globalLeftRightPadding = 30;
          globalTopPadding = flutterSafeAreaTop;
        } else {
          // this case, it's over 30. probably means
          // a rectangle android. so no need to make
          // it like 30

          globalBottomPadding = flutterSafeAreaBottom + 15;
          globalLeftRightPadding = 15;
          globalTopPadding = flutterSafeAreaTop;
        }
      }

      globallPaddingHasBeenSet = true;
    }

    return FutureBuilder(
      future: _dataLoadingFuture,
      builder: (context, snapshot) {
          
          //if (!Platform.isIOS){print("is androud");} // I love androud
          //I also love androud
        return AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          
          child: (snapshot.connectionState == ConnectionState.done)
          ? PopScope(
            //for switch animation
            key: ValueKey(1),

            // lets us prevent back button on map page
            canPop: false,
            onPopInvokedWithResult: (didPop, result) { 
              // when journey is showing and pop was attempted, clear journey
              if (_journeyOverlayActive) {
                _clearJourneyOverlays();
              }

              // If showing a persistent bottom sheet, close it.
              // Fix android back button for buildings sheet and journey sheet (doesn't work without this)
              if (_bottomSheetController != null) {
                _bottomSheetController!.close();
                _bottomSheetController = null;
                _removeSearchLocationMarker();
              }
            },
            child: Stack(
              children: [

                // underlying map layer (different ios and android)
                Platform.isIOS?
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
                        : _allDisplayedStopMarkers,
                    darkMapStyle: _darkMapStyle,
                    lightMapStyle: _lightMapStyle,
                    onMapCreated: _onMapCreated,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                  )
                : AndroidMap(
                    initialCenter: _defaultCenter,
                    polylines: _journeyOverlayActive
                        ? _displayedJourneyPolylines
                        : _displayedPolylines.union(_displayedJourneyPolylines),
                    staticMarkers: _journeyOverlayActive
                        ? _displayedJourneyMarkers
                              .union(
                                _searchLocationMarker != null
                                    ? {_searchLocationMarker!}
                                    : {},
                              )
                        : _displayedStopMarkers
                              .union(_displayedJourneyMarkers)
                              .union(
                                _searchLocationMarker != null
                                    ? {_searchLocationMarker!}
                                    : {},
                              ),
                    darkMapStyle: _darkMapStyle,
                    lightMapStyle: _lightMapStyle,
                    dynamicMarkers: _journeyOverlayActive
                        ? _displayedJourneyBusMarkers
                        : _displayedBusMarkers,
                    onMapCreated: _onMapCreated,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    //myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    //zoomControlsEnabled: true,
                    //mapToolbarEnabled: true,
                ),
            
                Padding(
                  padding: EdgeInsets.only(
                    top: globalTopPadding, bottom: globalBottomPadding, left: globalLeftRightPadding, right: globalLeftRightPadding, 
                  ),
                  child: Column(
                    children: [
                      // if showing journey, show header
                      (_journeyOverlayActive)
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: getColor(context, ColorType.background),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(56),
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
                                      horizontal: 15,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      "Showing route on map",
                                      style: TextStyle(
                                        fontFamily: 'Urbanist',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            // not showing journey, show usual header
                          :DecoratedBox(
                            decoration: BoxDecoration(
                              // boxShadow: [
                              //   BoxShadow(
                              //     color: isDarkMode(context) ? Colors.black.withAlpha(50) : Colors.white.withAlpha(100),
                              //     spreadRadius: 50,
                              //     blurRadius: 50,
                              //   )
                              // ]
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Container( // group maize and bus together on the left
                                //   child: Row(children: [
                                //     Text(
                                //       'maize',
                                //       style: TextStyle(
                                //         color: maizeBusYellow,
                                //         fontWeight: FontWeight.w800,
                                //         fontSize: 30
                                //       ),
                                //     ),
                                //     Text(
                                //       'bus',
                                //       style: TextStyle(
                                //         color: isDarkMode(context) ? maizeBusBlueDarkMode : maizeBusBlue,
                                //         fontWeight: FontWeight.w800,
                                //         fontSize: 30,
                                //       ),
                                //     ),
                                //   ],),
                                // ),
              
                                // SizedBox(
                                //   width: 45,
                                //   height: 45,
                                //   child: FittedBox(
                                //     child: DecoratedBox(
                                //       decoration: BoxDecoration(
                                //         boxShadow: [
                                //           BoxShadow(
                                //             color: getColor(context, ColorType.mapButtonShadow),
                                //             blurRadius: 10,
                                //             offset: Offset(0, 6)
                                //           )
                                //         ],
                                //         borderRadius: BorderRadius.circular(25)
                                //       ),
                                //       child: FloatingActionButton(
                                //         onPressed: () async {
                                //           // switch to settings menu
                                //           // with the MaterialPagesRoute animation
                                //           Navigator.push(
                                //             context,
                                //             MaterialPageRoute<void>(
                                //               builder: (context) => Settings(),
                                //             ),
                                //           );
                                //         },
                                //         heroTag: 'settings_fab',
                                //         elevation: 0,
                                //         child: Icon(
                                //           Icons.menu,
                                //           color: getColor(context, ColorType.mapButtonIcon),
                                //           size: 28,
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ),
                              ],
                            )
                          ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _isOffline
                            ? Padding(
                                key: const ValueKey('offline-banner'),
                                padding: EdgeInsets.only(
                                  top: 15,
                                  left: globalLeftRightPadding,
                                  right: globalLeftRightPadding,
                                  bottom: 10,
                                ),
                                child: _buildOfflineBanner(),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('offline-banner-hidden'),
                              ),
                      ),

                      // reminder widget
                      SizedBox(height: 30.0,),
                      ReminderWidgets(),
                       
                      Spacer(),
                      
                      // temp row (might add settings button to it later)
                      (!_journeyOverlayActive)
                          ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: 20
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  spacing: 10,
                                  children: [
                                    // face north button is only visible when not facing north
                                    Visibility(
                                      visible: _currentCameraPos != null && _currentCameraPos!.bearing != 0,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: getColor(context, ColorType.mapButtonShadow).withAlpha(50),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)
                                            )
                                          ],
                                          borderRadius: BorderRadius.circular(25)
                                        ),
                                        child: FloatingActionButton.small(
                                          onPressed: _setMapToNorth,
                                          heroTag: 'north_fab',
                                          backgroundColor: getColor(context, ColorType.mapButtonSecondary),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(56),
                                          ),
                                          child: Transform.rotate(
                                            angle: _currentCameraPos != null ? (-_currentCameraPos!.bearing - 45) * (math.pi / 180) : 0,
                                            child: Icon(
                                              FontAwesomeIcons.compass,
                                              color: getColor(context, ColorType.mapButtonPrimary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                      
                                  ],
                                )
                              ],
                            ),
                          )
                          : SizedBox.shrink(),
                              
                      // if showing journey, show close and reopen button
                      (_journeyOverlayActive)
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16)
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _showJourneySheetOnReopen,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: getColor(context, ColorType.importantButtonBackground),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(56),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    elevation: 1,
                                  ),
                                  icon: Icon(
                                    color: getColor(context, ColorType.importantButtonText),
                                    Icons.keyboard_arrow_up,
                                    size: 18,
                                  ), // The icon on the left
                                  label: Text(
                                    'Steps',
                                    style: TextStyle(
                                      color: getColor(context, ColorType.importantButtonText),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),                                    
                                  ), // The text on the right
                                ),
                              ),
                  
                              SizedBox(width: 20,),
                  
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(56)
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _clearJourneyOverlays,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: getColor(context, ColorType.secondaryButtonBackground),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(56),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    elevation: 1,
                                  ),
                                  icon: Icon(
                                    Icons.close,
                                    color: getColor(context, ColorType.secondaryButtonText),
                                    size: 18,
                                  ), // The icon on the left
                                  label: Text(
                                    'Close',
                                    style: TextStyle(
                                      color: getColor(context, ColorType.secondaryButtonText),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ), // The text on the right
                                ),
                              ),
                            ],
                          )
                          
                          // else, main buttons row
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              
                              children: [
                                
                                // routes
                                SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: FittedBox(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: getColor(context, ColorType.mapButtonShadow),
                                            blurRadius: 10,
                                            offset: Offset(0, 6)
                                          )
                                        ],
                                        borderRadius: BorderRadius.circular(25)
                                      ),
                                      child: FloatingActionButton(
                                        onPressed: () async {
                                          if (canVibrate && Platform.isIOS){
                                            await Haptics.vibrate(HapticsType.light);
                                          }
                                          _showBusRoutesModal(busProvider.routes,);
                                        },
                                        heroTag: 'routes_fab',
                                        elevation: 0, // handle shadow ourselves
                                        child: Icon(
                                          Icons.directions_bus,
                                          color: getColor(context, ColorType.mapButtonIcon),
                                          size: 30,
                                        ),
                                      ),
                                    )
                                  ),
                                ),
                            
                                SizedBox(width: 5),
                
                                // favorites
                                SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: FittedBox(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: getColor(context, ColorType.mapButtonShadow),
                                            blurRadius: 10,
                                            offset: Offset(0, 6)
                                          )
                                        ],
                                        borderRadius: BorderRadius.circular(25)
                                      ),
                                      child: FloatingActionButton(
                                        onPressed: () async {
                                          if (canVibrate && Platform.isIOS){
                                            await Haptics.vibrate(HapticsType.light);
                                          }
                                          _showFavoritesSheet();
                                        },
                                        heroTag: 'favorites_fab',
                                        elevation: 0,
                                        child: Icon(
                                          Icons.favorite,
                                          color: getColor(context, ColorType.mapButtonIcon),
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                
                                SizedBox(width: 5),
                
                                
                                // search
                                // Expanded( // stretch width
                                  // child: 
                                  SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: getColor(context, ColorType.mapButtonShadow),
                                            blurRadius: 10,
                                            offset: Offset(0, 6)
                                          )
                                        ],
                                        borderRadius: BorderRadius.circular(25)
                                      ),
                                      child: FloatingActionButton(
                                        onPressed: () async {
                                          if (canVibrate && Platform.isIOS){
                                            await Haptics.vibrate(HapticsType.light);
                                          }
                                          _showSearchSheet();
                                        },
                                        // style: ElevatedButton.styleFrom(
                                        //   alignment: Alignment.centerLeft,
                                        //   padding: const EdgeInsets.symmetric(
                                        //     horizontal: 13,
                                        //     vertical: 8,
                                        //   ),
                                        // ),
                                        child: Icon(
                                          Icons.search_sharp,
                                          color: getColor(context, ColorType.mapButtonIcon),
                                          size: 15,
                                        ),
                                        // label: Text(
                                        //   "where to?",
                                        //   style: TextStyle(
                                        //     color: getColor(context, ColorType.mapButtonIcon).withAlpha(214),
                                        //     fontSize: 18,
                                        //   )
                                        // ),
                                      ),
                                    ),
                                  ),
                                // ),
                              ],
                            ),
                    ],
                  ),
                )
              ],
            ),
          )
          : Container(
            //for switch animation
            key: ValueKey(0),

            color: getColor(context, ColorType.background),
            
            child: ValueListenableBuilder<Loadpoint>(
              valueListenable: _loadingMessageNotifier,
              builder: (context, loadpoint, child) {
                return LoadingScreen(loadpoint: loadpoint);
              }
            )
          )
          
        );

      }
    );
  }
}
