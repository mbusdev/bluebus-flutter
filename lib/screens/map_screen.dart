import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:bluebus/screens/new_features_screen.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:bluebus/widgets/bus_sheet.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
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
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import './settings.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';
//import 'dart:convert';

final NEW_BUTTON_SHOW_TIME = DateTime.parse("2026-03-16 00:00:00Z");
final NEW_BUTTON_HIDE_TIME = DateTime.parse("2026-03-24 00:00:00Z");

// Function to calculate rotation angle between two geographical points
// (used for bus stop icon orientation)
double pointRotation(double lat1, double lon1, double lat2, double lon2) {
  const double degToRad = 0.017453292519943295; // π / 180
  const double radToDeg = 57.29577951308232; // 180 / π

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



class MaizeBusCore extends StatefulWidget {
  const MaizeBusCore({super.key});

  @override
  State<MaizeBusCore> createState() => _MaizeBusCoreState();
}

class _MaizeBusCoreState extends State<MaizeBusCore> {
  late bool canVibrate = false;
  late Journey currDisplayed;
  ScreenRadius? screenRadius;
  bool screenRadiusLoaded = false;

  Future<void>? _dataLoadingFuture;
  final _loadingMessageNotifier = ValueNotifier<Loadpoint>(
    Loadpoint("Initializing...", 0),
  );
  GoogleMapController? _mapController;
  CameraPosition? _currentCameraPos;
  bool? _userLocVisible;
  static const _defaultCenter = LatLng(42.276463, -83.7374598);
  static LatLng startLatLng = _defaultCenter;

  Set<Polyline> _displayedPolylines = {};
  Map<String, Marker> _displayedStopMarkers = {}; // maps from stopID to marker
  Map<String, Marker> _displayedFavoriteStopMarkers = {};
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

  // In memory cache of favorited stop ids for quick lookup and immediate UI updates
  final Set<String> _favoriteStops = <String>{};


  Marker? _searchLocationMarker;
  final Set<String> _selectedRoutes = <String>{};
  List<Map<String, String>> _availableRoutes = [];
  Map<String, bool> _stopIsRide = {};

  // Custom marker icons
  // BitmapDescriptor? _busIcon;
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _rideStopIcon;
  BitmapDescriptor? _favStopIcon;
  BitmapDescriptor? _favRideStopIcon;
  BitmapDescriptor? _getOn;
  BitmapDescriptor? _getOff;

  // // Route specific bus icons
  // final Map<String, BitmapDescriptor> _routeBusIcons = {};

  // Memoization caches
  final Map<String, Polyline> _routePolylines = {};
  final Map<String, Map<String, Marker>> _routeStopMarkers = {}; // maps from route to a map of stopID to marker
  // Whether a journey search overlay is currently active (shows only journey path)
  bool _journeyOverlayActive = false;
  // maximum allowed distance (meters) from a stop to a candidate polyline point
  // static const double _maxMatchDistanceMeters = 150.0;
  // route ids that are part of the active journey
  final Set<String> _activeJourneyBusIds = {};
  // route ids of routes used in the active journey
  final Set<String> _activeJourneyRoutes = {};
  // cache last directions request origin/dest coordinates (used for VIRTUAL_* stops)
  Map<String, double>? _lastJourneyRequestOrigin;
  Map<String, double>? _lastJourneyRequestDest;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  // Provider listener for route updates
  BusProvider? _busProviderRef;
  VoidCallback? _busProviderListener;
  int _routesFingerprint = 0;

  // store persistent bottom sheet controller
  PersistentBottomSheetController? _bottomSheetController;

  final BaseRoutesLayer baseRoutesLayer = BaseRoutesLayer();
  final LiveBusesLayer liveBusesLayer = LiveBusesLayer();
  final JourneyLayer journeyLayer = JourneyLayer();

  // GoogleMaps styles
  String _darkMapStyle = "{}";
  String _lightMapStyle = "{}";

  Future _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/maps_dark_style.json');
    _lightMapStyle = await rootBundle.loadString(
      'assets/maps_light_style.json',
    );
  }

  @override
  void initState() {
    super.initState();
    _setupConnectivityMonitoring();

    baseRoutesLayer.init(_favoriteStops, _selectedRoutes, onStopClicked);
    journeyLayer.init(_showBusSheet, _activeJourneyBusIds, _activeJourneyRoutes, context);

    hideJourney(); // Hide the journey layer until we're ready to use it
    

    // TODO: Make sure this still works when moved to line 197
    // // Only update bus markers when buses change
    // final busProvider = Provider.of<BusProvider>(context, listen: false);
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (busProvider.buses.isNotEmpty) {
    //     _updateDisplayedBuses(busProvider.buses);
    //   }
    // });


    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _busProviderRef = Provider.of<BusProvider>(context, listen: false);
        _busProviderListener = () {
          liveBusesLayer.init(_busProviderRef?.buses ?? [], _selectedRoutes, onBusClicked); // TODO: Should this init be somewhere else? I need it to have access to the busProvider I think


          final routes = _busProviderRef?.routes ?? [];
          final newFp = _computeRoutesFingerprint(routes);
          if (newFp != _routesFingerprint) {
            _routesFingerprint = newFp;
            _handleRoutesUpdated(routes);
          }

          if (_busProviderRef!.buses.isNotEmpty) {
            _updateDisplayedBuses(_busProviderRef!.buses);
          }
        };
        _busProviderRef?.addListener(_busProviderListener!);
      } catch (e, stackTrace) {
        debugPrint(
          'Error obtaining BusProvider or registering route listener in MapScreen.initState: $e',
        );
        debugPrint(stackTrace.toString());
      }
    });
  }

  void onStopClicked(BusStop stop) {
    try {
      Haptics.vibrate(HapticsType.light);
    } catch (e) {}

    _showStopSheet(
      stop.id,
      stop.name,
      stop.location.latitude,
      stop.location.longitude,
    );
  }

  void onBusClicked(Bus b) {
    _showBusSheet(b.id);
  }

  Future<void> _setupConnectivityMonitoring() async {
    final connectivity = Connectivity();

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
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
    // debugPrint("******** Got didChangeDependencies call");
    super.didChangeDependencies();
    if (_dataLoadingFuture == null) {
      _dataLoadingFuture = _loadAllData();
    }
  }

  Future<void> _loadAllData() async {

    // debugPrint("******* Loading all data");

    ThemeProvider theme = Provider.of<ThemeProvider>(context, listen: false);
    theme.onSystemThemeUpdate(context);
    await theme.loadTheme(); 

    // debugPrint("******* Loaded theme");

    screenRadius = await ScreenCornerRadius.get(); // load screen radius
    screenRadiusLoaded = true;

    // debugPrint("******* Loaded screenRadius");
    
    //Trying to find the location of the user to set initial position. If not found, defaults to _defaultCenter
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // permission = await Geolocator.requestPermission();
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null){
        startLatLng = LatLng(pos.latitude, pos.longitude);
      }
    }
    // debugPrint("******* Got geolocator position");
    

    // debugPrint("******* Loading canVibrate");

            
    canVibrate = await Haptics.canVibrate();
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    _loadingMessageNotifier.value = Loadpoint('Contacting server...', 1);
    StartupDataHolder? startupData = await _getStartupData();

    // keep trying to reach server. Can't start without this
    while (startupData == null) {
      if (kDebugMode) {
        debugPrint("retrying _getStartupData");
      }
      await Future.delayed(Duration(seconds: 2));
      startupData = await _getStartupData();
    }

    // moving this here fixes loading bug
    await RouteColorService.initialize();

    if (!isCurrentVersionEqualOrHigher(startupData.version)) {
      showUndismissableMaizebusDialog(
        contextIn: context,
        title: Text(startupData.updateTitle),
        content: Text(startupData.updateMessage),
      );
    }

    if (startupData.persistantMessageTitle != '') {
      showMaizebusOKDialog(
        contextIn: context,
        title: startupData.persistantMessageTitle,
        content: startupData.persistantMessage,
      );
    }
    
    // debugPrint("******* Loading all the data in parallel");
    // loading all this data in parallel
    await Future.wait([
      _loadCustomMarkers(),
      busProvider.loadRoutes(),
      _loadSelectedRoutes(),
      _loadFavoriteStops(),
    ]);

    // actions that depend on the data loaded earlier
    _loadingMessageNotifier.value = Loadpoint('Loading bus images...', 2);
    await MapImageService.loadData();
    // await _loadRouteSpecificBusIcons();
    _updateAvailableRoutes(busProvider.routes);
    _cacheRouteOverlays(busProvider.routes);
    
    debugPrint("******* Caching routes");
    baseRoutesLayer.cacheRoutes(busProvider.routes);

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

    // debugPrint("******* FINISHED ALL LOADING!!!!");
    
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
          final name = normalizeStopName(stop['name'] as String);
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
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
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
      // [These were moved to composite_map_widget.dart]
      // _stopIcon = await resizeImage(
      //   await rootBundle.load('assets/busStop.png'),
      // );
      // _rideStopIcon = await resizeImage(
      //   await rootBundle.load('assets/busStopRide.png'),
      // );
      // _favStopIcon = await resizeImage(
      //   await rootBundle.load('assets/favbusStop.png'),
      // );
      // _favRideStopIcon = await resizeImage(
      //   await rootBundle.load('assets/favbusStopRide.png'),
      // );
      // _getOn = await MapImageService.resizeImage(await rootBundle.load('assets/getOn.png'));
      // _getOff = await MapImageService.resizeImage(await rootBundle.load('assets/getOff.png'));
      // TODO: Move this into map_image_service.dart

      // Load route specific bus icons
      // await _loadRouteSpecificBusIcons();
      await MapImageService.loadData(); // TODO: This was already called inside loadAllData. Do we need to call it again?

      // Refresh markers with new icons
      if (mounted) {
        _refreshAllMarkers();
      }
    } catch (e) {
      // Fallback to default markers if custom loading fails
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

  // // Load route specific bus icons from the backend
  // Future<void> _loadRouteSpecificBusIcons() async {
  //   try {
  //     if (!RouteColorService.isInitialized) {
  //       await RouteColorService.initialize();
  //     }

  //     // Check if we need to update cached assets based on version
  //     final shouldRefreshAssets = await _shouldRefreshCachedAssets();

  //     final routeIds = RouteColorService.definedRouteIds;

  //     for (final routeId in routeIds) {
  //       // Try to load from cache first if not forcing refresh
  //       if (!shouldRefreshAssets) {
  //         final cachedIcon = await _loadCachedBusIcon(routeId);
  //         if (cachedIcon != null) {
  //           _routeBusIcons[routeId] = cachedIcon;
  //           continue;
  //         }
  //       }

  //       // Load from backend if cache miss or forcing refresh
  //       final imageUrl = RouteColorService.getRouteImageUrl(routeId);
  //       if (imageUrl != null) {
  //         await _loadRouteBusIcon(routeId, imageUrl);
  //       } else {
  //         _setFallbackBusIcon(routeId);
  //       }
  //     }
  //   } catch (e) {
  //     // Fallback to default bus icon
  //     _busIcon = BitmapDescriptor.defaultMarkerWithHue(
  //       BitmapDescriptor.hueYellow,
  //     );
  //   }
  // }





  // // Check if cached assets need to be refreshed based on backend version
  // Future<bool> _shouldRefreshCachedAssets() async {
  //   int frontEndVer;
  //   frontEndVer = await getFrontEndImageVer();

  //   try {
  //     final backendImageVersion = await _getBackendImageVersion();
  //     if (backendImageVersion == null) {
  //       return true; // if you can't reach the server give up
  //     }
  //     if (int.parse(backendImageVersion) == frontEndVer) {
  //       return false;
  //     } else {
  //       await setFrontEndImageVer(int.parse(backendImageVersion));
  //       return true;
  //     }
  //   } catch (e) {
  //     // On error, assume refresh needed
  //     return true;
  //   }
  // }

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
          p_message['subtitle'],
        );
      } else if (kDebugMode) {
        debugPrint(
          "Got non-OK response for startup data: ${response.statusCode}",
        );
        debugPrint(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Couldn't load startup data: ${e.toString()}");
      }
      return null;
    }
    return null;
  }

  // // Get minimum supported version from backend
  // Future<String?> _getBackendImageVersion() async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('${BACKEND_URL}/getStartupInfo'),
  //     );
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       return data['bus_image_version'] as String?;
  //     }
  //   } catch (e) {
  //     // Return null on error - will trigger refresh
  //   }
  //   return null;
  // }

  // // Load cached bus icon from SharedPreferences
  // Future<BitmapDescriptor?> _loadCachedBusIcon(String routeId) async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final cachedBytes = prefs.getString('bus_icon_$routeId');
  //     if (cachedBytes != null) {
  //       final bytes = base64.decode(cachedBytes);
  //       return BitmapDescriptor.fromBytes(bytes);
  //     }
  //   } catch (e) {
  //     // Return null on error
  //   }
  //   return null;
  // }






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

    if (_busProviderRef != null && _busProviderListener != null) {
      try {
        _busProviderRef!.removeListener(_busProviderListener!);
      } catch (e, stackTrace) {
        debugPrint(
          'Error removing _busProviderListener in MapScreen.dispose: $e',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _mapController?.dispose();
    super.dispose();
  }

  // Compute a lightweight fingerprint of the routes list to detect changes
  int _computeRoutesFingerprint(List<BusRouteLine> routes) {
    int h = 1;
    for (final r in routes) {
      h = 31 * h + r.routeId.hashCode;
      // include geometry hash computed over element values
      h = 31 * h + Object.hashAll(r.points);
      h = 31 * h + (r.color?.value ?? 0);
    }
    return h;
  }

  // Called when provider reports routes changed
  void _handleRoutesUpdated(List<BusRouteLine> routes) {
    // Evict stale cached overlays for routes that changed
    final newKeys = routes
        .map((r) => '${r.routeId}_${Object.hashAll(r.points)}')
        .toSet();
    final newRouteIds = routes.map((r) => r.routeId).toSet();

    journeyLayer.setRoutesCache(routes);

    _routePolylines.removeWhere((key, _) {
      for (final id in newRouteIds) {
        if (key.startsWith('${id}_') && !newKeys.contains(key)) {
          return true;
        }
      }
      return false;
    });

    _routeStopMarkers.removeWhere((key, _) {
      for (final id in newRouteIds) {
        if (key.startsWith('${id}_') && !newKeys.contains(key)) {
          return true;
        }
      }
      return false;
    });

    _updateAvailableRoutes(routes);
    _cacheRouteOverlays(routes);

    if (_selectedRoutes.isNotEmpty) {
      _updateDisplayedRoutes();
    } else {
      setState(() {});
    }
  }

  void _updateAvailableRoutes(List<BusRouteLine> routes) {
    // debugPrint("****** Got _updateAvailableRoutes call!!");
    final Map<String, String> routeIdToName = {};
    for (final r in routes) {
      if (!routeIdToName.containsKey(r.routeId)) {
        // Use backend route name if available, otherwise fallback to local names
        final name = RouteColorService.getRouteName(r.routeId);
        routeIdToName[r.routeId] = name;

        MapImageService.ensureRouteIconIsLoaded(r.routeId);
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
      // Create unique key for each route variant (content-based hash)
      final routeKey = '${r.routeId}_${Object.hashAll(r.points)}';
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
        _routeStopMarkers[routeKey] = {};
        for (final stop in r.stops) { // iterate through all stops in this route
          final isFavorite = _favoriteStops.contains(stop.id);
          
          final marker = Marker(
            markerId: MarkerId(
              'stop_${stop.id}_${Object.hashAll(r.points)}',
            ),
            position: stop.location,
            flat: true,
            icon: isFavorite
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
              try {
                Haptics.vibrate(HapticsType.light);
              } catch (e) {}

              _showStopSheet(
                stop.id,
                stop.name,
                stop.location.latitude,
                stop.location.longitude,
              );
            },
            rotation: stop.rotation,
            anchor: Offset(0.5, 0.5),
          );
          _routeStopMarkers[routeKey]?[stop.id] = marker;

          // gets first marker of this stop and adds it to the favorited stop markers 
          if (isFavorite && !_displayedFavoriteStopMarkers.containsKey(stop.id)) {
            _displayedFavoriteStopMarkers[stop.id] = marker;
          }
          _stopIsRide[stop.id] = stop.isRide;
        }
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
        baseRoutesLayer.reload(); // Reload the markers to include the new favorite
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
        baseRoutesLayer.reload(); // Reload the markers to include the new favorite
      });
      _setStopFavorited(stpid, false);
    }
  }

  // Update cached markers for a specific stop id to reflect favorite/unfavorite
  void _setStopFavorited(String stpid, bool favored) {
    // Update all routeStopMarkers entries that match this stop id
    final isRide = _stopIsRide[stpid] ?? false;
    _routeStopMarkers.forEach((routeKey, markers) {
      // if marker does not exist in this route, return
      if (!markers.containsKey(stpid)) return;

      final m = markers[stpid]!; // get old marker
      final newMarker = Marker(
        flat: true,
        markerId: m.markerId,
        position: m.position,
        icon: favored
                ? (isRide
                      ? _favRideStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )
                      : _favStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ))
                : (isRide
                      ? _rideStopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )
                      : _stopIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            )),
        consumeTapEvents: m.consumeTapEvents,
        onTap: m.onTap,
        rotation: m.rotation,
        anchor: m.anchor,
      );

      // gets first marker of this stop id and adds it to the favorited stop markers 
      if (favored && !_displayedFavoriteStopMarkers.containsKey(stpid)) {
        _displayedFavoriteStopMarkers[stpid] = newMarker;
      }

      markers[stpid] = newMarker; // set as new marker
    });

    // remove favorite stop marker if not favored
    if (!favored) {
      _displayedFavoriteStopMarkers.remove(stpid);
    }

    // If displayed, update displayed markers as well
    setState(() {
      // Rebuild displayed stop markers based on current selected routes
      final selectedStopMarkers = <String, Marker>{};
      for (final routeId in _selectedRoutes) {
        final routeVariants = _routePolylines.keys.where(
          (key) => key.startsWith('${routeId}_'),
        );
        for (final routeKey in routeVariants) {
          final stops = _routeStopMarkers[routeKey];
          if (stops == null) continue;

          // iterate through and add the stop markers
          // if they are not already in the selected stop markesr
          stops.forEach((key, value) {
            if (!selectedStopMarkers.containsKey(key)) {
              selectedStopMarkers[key] = value;
            }
          });
        }
      }
      _displayedStopMarkers = selectedStopMarkers;
      _updateAllDisplayedMarkers();
    });
  }

  void _updateDisplayedRoutes() {
    final selectedPolylines = <Polyline>{};
    final selectedStopMarkers = <String, Marker>{};

    for (final routeId in _selectedRoutes) {
      // Find all variants of this route
      final routeVariants = _routePolylines.keys.where(
        (key) => key.startsWith('${routeId}_'),
      );

      for (final routeKey in routeVariants) {
        final polyline = _routePolylines[routeKey];
        if (polyline != null) selectedPolylines.add(polyline);
        final stops = _routeStopMarkers[routeKey];
        if (stops == null) continue;
          
        stops.forEach((key, value) {
          if (!selectedStopMarkers.containsKey(key)) {
            selectedStopMarkers[key] = value;
          }
        });
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
    debugPrint("****** Updating displayed buses");
    // // null case or error contacting server case
    // if (allBuses == []) return;

    // final selectedBusMarkers = allBuses
    //     .where((bus) => _selectedRoutes.contains(bus.routeId))
    //     .map((bus) {
    //       // Use backend color if available, otherwise fallback to service
    //       final routeColor =
    //           bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);

    //       // Use route specific bus icon if available, otherwise fallback to default
    //       BitmapDescriptor? busIcon;
    //       if (_routeBusIcons.containsKey(bus.routeId)) {
    //         busIcon = _routeBusIcons[bus.routeId];
    //       } else if (_busIcon != null) {
    //         busIcon = _busIcon;
    //       } else {
    //         busIcon = BitmapDescriptor.defaultMarkerWithHue(
    //           _colorToHue(routeColor),
    //         );
    //       }

    //       return Marker(
    //         flat: true,
    //         markerId: MarkerId('bus_${bus.id}'),
    //         consumeTapEvents: true,
    //         position: bus.position,
    //         icon: busIcon!,
    //         rotation: bus.heading,
    //         anchor: const Offset(0.5, 0.5), // Center the icon on the position
    //         onTap: () {
    //           try {
    //             Haptics.vibrate(HapticsType.light);
    //           } catch (e) {}
    //           _showBusSheet(bus.id);
    //         },
    //       );
    //     })
    //     .toSet();

    journeyLayer.refreshLiveBusMarkers(allBuses);

    // Update journey bus markers if journey is active
    // if (_journeyOverlayActive && _activeJourneyBusIds.isNotEmpty) {
    //   _displayedJourneyBusMarkers.clear();
    //   for (final bus in allBuses) {
    //     // Show buses that are on routes used in the journey
    //     if (_activeJourneyBusIds.contains(bus.id)) {
    //       BitmapDescriptor busIcon = MapImageService.getBusIcon(bus);
          

    //       _displayedJourneyBusMarkers.add(
    //         Marker(
    //           flat: true,
    //           markerId: MarkerId('journey_bus_${bus.id}'),
    //           consumeTapEvents: true,
    //           position: bus.position,
    //           icon: busIcon!,
    //           rotation: bus.heading,
    //           anchor: const Offset(0.5, 0.5),
    //           onTap: () => _showBusSheet(bus.id),
    //         ),
    //       );
    //     }
    //   }
    // }

    setState(() {
      // _displayedBusMarkers = selectedBusMarkers;
      _updateAllDisplayedMarkers(); // TODO: Do we still need this?

      liveBusesLayer.reload();
    });
  }

  void _updateAllDisplayedMarkers() {
    _allDisplayedStopMarkers = _displayedStopMarkers.values.toSet()
        .union(_displayedFavoriteStopMarkers.values.toSet())
        .union(_displayedBusMarkers)
        .union(_displayedJourneyMarkers)
        .union(_searchLocationMarker != null ? {_searchLocationMarker!} : {});
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
    // TODO: Should all this be moved inside the MapImageService now that we're encapsulating everything in that?
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    _refreshCachedStopMarkers();
    // _refreshRouteBusIcons();
    MapImageService.refreshRouteBusIcons(); 
    _updateDisplayedRoutes();
    _updateDisplayedBuses(busProvider.buses);
  }

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
    // also clear persistent favorited stop markers to be refreshed in _cacheRouteOverlays(..)
    _displayedFavoriteStopMarkers.clear();
    // Re-cache all route overlays with the new icons
    _cacheRouteOverlays(
      Provider.of<BusProvider>(context, listen: false).routes,
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
                baseRoutesLayer.reload();
              });
              // _updateDisplayedRoutes();

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
    debugPrint(">>>>>>> SHOWING SEARCH SHEEEEEET");
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
    _bottomSheetController?.closed.then((_) {hideJourney();});
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
          builder: (context, scrollController) {
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

                currDisplayed = journey;
                showJourney();
                journeyLayer.setJourney(journey, getColor(context, ColorType.opposite));

                // TODO: Figure out how to change the visibility of the layers

                // _displayJourneyOnMap(
                //   journey,
                //   getColor(context, ColorType.opposite),
                // );
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
    _bottomSheetController?.closed.then((_) {hideJourney();});
  }

  _showJourneySheetOnReopen() {
    debugPrint(">>>>> Showing journey sheet on reopen");
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
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 15),
                  JourneyBody(journey: currDisplayed),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      debugPrint("***** Modal bottom sheet is complete!!");
      hideJourney();
    });
  }
 
  // TODO: Put this into composite_map_widget.dart
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

  // Display a Journey on the map
  // void _displayJourneyOnMap(Journey journey, Color walkLineColor) async {
    
  // }

  void showJourney() {
    debugPrint("**** showJourney call");
    journeyLayer.isVisible = true;
    baseRoutesLayer.isVisible = false;
    liveBusesLayer.isVisible = false;
  }

  void hideJourney() {
    debugPrint("**** hideJourney call");
    journeyLayer.isVisible = false;
    baseRoutesLayer.isVisible = true;
    liveBusesLayer.isVisible = true;
  }

  // Clear/hide the currently displayed journey overlays and return to normal route view
  // void _clearJourneyOverlays() {
  //   journeyLayer.clearJourney();
  //   // if (!_journeyOverlayActive) return;
  //   // _displayedJourneyPolylines.clear();
  //   // _displayedJourneyMarkers.clear();
  //   // _displayedJourneyBusMarkers.clear();
  //   // _activeJourneyBusIds.clear();
  //   // _activeJourneyRoutes.clear();
  //   // _journeyOverlayActive = false;
  //   // // making sure to remove search location marker when clearing journey
  //   // _removeSearchLocationMarker();
  //   // setState(() {});
  // }

  // // Haversine distance between two LatLngs in meters
  // double _haversineDistanceMeters(LatLng a, LatLng b) {
  //   const R = 6371000; // Earth radius in meters
  //   final lat1 = a.latitude * math.pi / 180.0;
  //   final lat2 = b.latitude * math.pi / 180.0;
  //   final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  //   final dLon = (b.longitude - a.longitude) * math.pi / 180.0;

  //   final sa =
  //       math.sin(dLat / 2) * math.sin(dLat / 2) +
  //       math.cos(lat1) *
  //           math.cos(lat2) *
  //           math.sin(dLon / 2) *
  //           math.sin(dLon / 2);
  //   final c = 2 * math.atan2(math.sqrt(sa), math.sqrt(1 - sa));
  //   return R * c;
  // }

  // // Find nearest index and its distance on polyline to target. Returns a pair [index, distanceMeters]
  // List<dynamic> _nearestIndexAndDistanceOnPolyline(
  //   List<LatLng> poly,
  //   LatLng target,
  // ) {
  //   int bestIdx = 0;
  //   double bestDist = double.infinity;
  //   for (int i = 0; i < poly.length; i++) {
  //     final p = poly[i];
  //     final d = _haversineDistanceMeters(p, target);
  //     if (d < bestDist) {
  //       bestDist = d;
  //       bestIdx = i;
  //     }
  //   }
  //   return [bestIdx, bestDist];
  // }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) async {
    _currentCameraPos = position;
  }

  void _onCameraIdle() async {
    // check if user location is within viewport bounds
    LatLngBounds? viewportBounds = await _mapController?.getVisibleRegion();
    if (viewportBounds != null) {
      Position? pos = await _getLastKnownLocation();
      if (pos != null) {
        _userLocVisible = !viewportBounds.contains(
          LatLng(pos.latitude, pos.longitude),
        );
      }
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
                    title: "Error",
                    content: "Couldn't load stop.",
                  );
                }
              },
            );
          },
        ),
      ),
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
                title: 'Error',
                content: 'Couldn\'t load stop.',
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
          isFavorite: _favoriteStops.contains(stopID),
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
    ).then((_) { hideJourney(); }); // Hide any displayed journey when the sheet is closed
  }

  // lighter function for when we need to get location
  // over and over without constantly doing a full
  // hardware gps lock
  Future<Position?> _getLastKnownLocation() async {
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
        return null;
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
          return null;
        }
        else {
          //Center map once right after user grants location permissions
          _centerOnLocation(true);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are denied. Please enable them in settings',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      return position;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return null;
  }

  Future<void> _centerOnLocation(
    bool userLocation, [
    double lat = 0,
    double long = 0,
  ]) async {
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
      Position? pos = await _getLastKnownLocation();
      if (pos != null) position = pos;
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
  }

  Future<void> _setMapToNorth() async {
    if (_mapController != null && _currentCameraPos != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCameraPos!.target, // current position
            zoom: _currentCameraPos!.zoom,
            bearing: 0, // face north
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    if (!globallPaddingHasBeenSet) {
      // set all padding
      // first, getting all the padding values
      final mediaQueryData = MediaQuery.of(context);
      final double flutterSafeAreaTop = mediaQueryData.padding.top;
      final double flutterSafeAreaBottom = mediaQueryData.padding.bottom;

      // screen buttons are 45 by 45 (diameter)
      // so they have a radius of 45/2 = 22.5
      // so for perfectly spaced buttons, we 
      // need to do screen radius - 22.5           
      double perfectPadding = (screenRadius?.bottomLeft ?? 0) - 22.5;

      if (Platform.isIOS) perfectPadding -= 9; // the -9 just makes it look more pretty on ios 

      globalTopPadding = flutterSafeAreaTop;

      // if we're padding less than 3 then its too rectangle.
      // default to just keeping it out of the safe area
      if (perfectPadding < 3){
        globalBottomPadding = flutterSafeAreaBottom + 10;
        globalLeftRightPadding = 10;

      } else if ((perfectPadding < flutterSafeAreaBottom) && !Platform.isIOS) {
        // if the buttons are in the safe area, act rectangular
        // but not for iOS, because safe area isn't real on iOS
        globalBottomPadding = flutterSafeAreaBottom + 10;
        globalLeftRightPadding = 10;

      } else {
        // perfect padding is perfect! it keeps the buttons
        // out of the safe area so we'll just use them 
        globalBottomPadding = perfectPadding;
        globalLeftRightPadding = perfectPadding;
      }

      // only set this to true if we've loaded the screen radius
      globallPaddingHasBeenSet = screenRadiusLoaded;
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
                    // if (_journeyOverlayActive) {
                    //   _clearJourneyOverlays();
                    // }
                    hideJourney(); // Hide the journey if it's showing right now

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
                      CompositeMapWidget(
                        initialCenter: startLatLng,
                        mapLayers: [
                          baseRoutesLayer,
                          liveBusesLayer,
                          journeyLayer
                        ],
                        onMapCreated: _onMapCreated,
                      ),

                      // underlying map layer (different ios and android)
                      // Platform.isIOS
                          // ? MapWidget(
                          //     initialCenter: startLatLng,
                          //     polylines: _journeyOverlayActive
                          //         ? _displayedJourneyPolylines
                          //         : _displayedPolylines.union(
                          //             _displayedJourneyPolylines,
                          //           ),
                          //     markers: _journeyOverlayActive
                          //         ? _displayedJourneyMarkers
                          //               .union(_displayedJourneyBusMarkers)
                          //               .union(
                          //                 _searchLocationMarker != null
                          //                     ? {_searchLocationMarker!}
                          //                     : {},
                          //               )
                          //         : _allDisplayedStopMarkers,
                          //     darkMapStyle: _darkMapStyle,
                          //     lightMapStyle: _lightMapStyle,
                          //     onMapCreated: _onMapCreated,
                          //     onCameraMove: _onCameraMove,
                          //     onCameraIdle: _onCameraIdle,
                          //     myLocationEnabled: true,
                          //     myLocationButtonEnabled: false,
                          //     zoomControlsEnabled: true,
                          //     mapToolbarEnabled: true,
                          //   )
                          // : AndroidMap(
                          //     initialCenter: startLatLng,
                          //     polylines: _journeyOverlayActive
                          //         ? _displayedJourneyPolylines
                          //         : _displayedPolylines.union(
                          //             _displayedJourneyPolylines,
                          //           ),
                          //     staticMarkers: _journeyOverlayActive
                          //         ? _displayedJourneyMarkers.union(
                          //             _searchLocationMarker != null
                          //                 ? {_searchLocationMarker!}
                          //                 : {},
                          //           )
                          //         : _displayedStopMarkers.values.toSet()
                          //               .union(_displayedFavoriteStopMarkers.values.toSet())
                          //               .union(_displayedJourneyMarkers)
                          //               .union(
                          //                 _searchLocationMarker != null
                          //                     ? {_searchLocationMarker!}
                          //                     : {},
                          //               ),
                          //     darkMapStyle: _darkMapStyle,
                          //     lightMapStyle: _lightMapStyle,
                          //     dynamicMarkers: _journeyOverlayActive
                          //         ? _displayedJourneyBusMarkers
                          //         : _displayedBusMarkers,
                          //     onMapCreated: _onMapCreated,
                          //     onCameraMove: _onCameraMove,
                          //     onCameraIdle: _onCameraIdle,
                          //     //myLocationEnabled: true,
                          //     myLocationButtonEnabled: false,
                          //     //zoomControlsEnabled: true,
                          //     //mapToolbarEnabled: true,
                          //   ),

                      Padding(
                        padding: EdgeInsets.only(
                          top: globalTopPadding,
                          bottom: globalBottomPadding,
                          left: globalLeftRightPadding,
                          right: globalLeftRightPadding,
                        ),
                        child: Column(
                          children: [
                            // if showing journey, show header
                            (_journeyOverlayActive)
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: getColor(
                                        context,
                                        ColorType.background,
                                      ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDarkMode(context)
                                              ? Colors.black.withAlpha(50)
                                              : Colors.white.withAlpha(100),
                                          spreadRadius: 50,
                                          blurRadius: 50,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          // group maize and bus together on the left
                                          child: Row(
                                            children: [
                                              Text(
                                                'maize',
                                                style: TextStyle(
                                                  color: maizeBusYellow,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 30,
                                                ),
                                              ),
                                              Text(
                                                'bus',
                                                style: TextStyle(
                                                  color: isDarkMode(context)
                                                      ? maizeBusBlueDarkMode
                                                      : maizeBusBlue,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 30,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        SizedBox(
                                          // width: 45,
                                          width: 105,
                                          height: 45,
                                          child: FittedBox(
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                (NEW_BUTTON_SHOW_TIME.isBefore(
                                                          DateTime.now(),
                                                        ) &&
                                                        NEW_BUTTON_HIDE_TIME
                                                            .isAfter(
                                                              DateTime.now(),
                                                            ))
                                                    ? CustomPaint(
                                                        foregroundPainter:
                                                            ProgressCirclePainter(
                                                              startTime:
                                                                  NEW_BUTTON_SHOW_TIME,
                                                              endTime:
                                                                  NEW_BUTTON_HIDE_TIME,
                                                              currentTime:
                                                                  DateTime.now(),
                                                            ),
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: getColor(
                                                                  context,
                                                                  ColorType
                                                                      .mapButtonShadow,
                                                                ),
                                                                blurRadius: 10,
                                                                offset: Offset(
                                                                  0,
                                                                  6,
                                                                ),
                                                              ),
                                                            ],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  25,
                                                                ),
                                                          ),
                                                          child: FloatingActionButton(
                                                            onPressed: () async {
                                                              // switch to settings menu
                                                              // with the MaterialPagesRoute animation
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute<
                                                                  void
                                                                >(
                                                                  builder:
                                                                      (
                                                                        context,
                                                                      ) =>
                                                                          NewFeaturesScreen(),
                                                                ),
                                                              );
                                                            },
                                                            heroTag: 'new_fab',
                                                            elevation: 0,
                                                            child: Text(
                                                              "New!",
                                                              style: TextStyle(
                                                                color: getColor(
                                                                  context,
                                                                  ColorType
                                                                      .mapButtonIcon,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : SizedBox.shrink(),

                                                SizedBox(width: 15),

                                                DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: getColor(
                                                          context,
                                                          ColorType
                                                              .mapButtonShadow,
                                                        ),
                                                        blurRadius: 10,
                                                        offset: Offset(0, 6),
                                                      ),
                                                    ],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          25,
                                                        ),
                                                  ),
                                                  child: FloatingActionButton(
                                                    onPressed: () async {
                                                      // switch to settings menu
                                                      // with the MaterialPagesRoute animation
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute<void>(
                                                          builder: (context) =>
                                                              Settings(),
                                                        ),
                                                      );
                                                    },
                                                    heroTag: 'settings_fab',
                                                    elevation: 0,
                                                    child: Icon(
                                                      Icons.menu,
                                                      color: getColor(
                                                        context,
                                                        ColorType.mapButtonIcon,
                                                      ),
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                            SizedBox(height: 30.0),
                            _journeyOverlayActive || _isOffline
                                ? SizedBox.shrink()
                                : Expanded(
                                    child: OverflowBox(
                                      maxHeight: double.infinity,
                                      alignment: Alignment.topRight,
                                      child: ReminderWidgets(),
                                    ),
                                  ),

                            Spacer(),

                            (!_journeyOverlayActive)
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Column(
                                          spacing: 10,
                                          children: [
                                            // face north button is only visible when not facing north
                                            Visibility(
                                              visible:
                                                  _currentCameraPos != null &&
                                                  _currentCameraPos!.bearing !=
                                                      0,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: getColor(
                                                        context,
                                                        ColorType
                                                            .mapButtonShadow,
                                                      ).withAlpha(50),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                                child: FloatingActionButton.small(
                                                  onPressed: _setMapToNorth,
                                                  heroTag: 'north_fab',
                                                  backgroundColor: getColor(
                                                    context,
                                                    ColorType
                                                        .mapButtonSecondary,
                                                  ),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          56,
                                                        ),
                                                  ),
                                                  child: Transform.rotate(
                                                    angle:
                                                        _currentCameraPos !=
                                                            null
                                                        ? (-_currentCameraPos!
                                                                      .bearing -
                                                                  45) *
                                                              (math.pi / 180)
                                                        : 0,
                                                    child: Icon(
                                                      FontAwesomeIcons.compass,
                                                      color: getColor(
                                                        context,
                                                        ColorType
                                                            .mapButtonPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // location button
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              child:
                                                  !(_userLocVisible == null ||
                                                      _userLocVisible!)
                                                  ?
                                                    // if not needed, sized box
                                                    SizedBox.shrink()
                                                  :
                                                    // otherwise, normal button
                                                    DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: getColor(
                                                              context,
                                                              ColorType
                                                                  .mapButtonShadow,
                                                            ).withAlpha(50),
                                                            blurRadius: 4,
                                                            offset: Offset(
                                                              0,
                                                              2,
                                                            ),
                                                          ),
                                                        ],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              25,
                                                            ),
                                                      ),
                                                      child: FloatingActionButton.small(
                                                        onPressed: () {
                                                          _centerOnLocation(
                                                            true,
                                                          );
                                                        },
                                                        heroTag: 'location_fab',
                                                        backgroundColor: getColor(
                                                          context,
                                                          ColorType
                                                              .mapButtonSecondary,
                                                        ),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                56,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.my_location,
                                                          color: getColor(
                                                            context,
                                                            ColorType
                                                                .mapButtonPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            56,
                                          ),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: _showJourneySheetOnReopen,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: getColor(
                                              context,
                                              ColorType
                                                  .importantButtonBackground,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(56),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 8,
                                            ),
                                            elevation: 1,
                                          ),
                                          icon: Icon(
                                            color: getColor(
                                              context,
                                              ColorType.importantButtonText,
                                            ),
                                            Icons.keyboard_arrow_up,
                                            size: 18,
                                          ), // The icon on the left
                                          label: Text(
                                            'Steps',
                                            style: TextStyle(
                                              color: getColor(
                                                context,
                                                ColorType.importantButtonText,
                                              ),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ), // The text on the right
                                        ),
                                      ),

                                      SizedBox(width: 20),

                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            56,
                                          ),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            hideJourney();
                                            // _clearJourneyOverlays
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: getColor(
                                              context,
                                              ColorType
                                                  .secondaryButtonBackground,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(56),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 8,
                                            ),
                                            elevation: 1,
                                          ),
                                          icon: Icon(
                                            Icons.close,
                                            color: getColor(
                                              context,
                                              ColorType.secondaryButtonText,
                                            ),
                                            size: 18,
                                          ), // The icon on the left
                                          label: Text(
                                            'Close',
                                            style: TextStyle(
                                              color: getColor(
                                                context,
                                                ColorType.secondaryButtonText,
                                              ),
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
                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [
                                      // routes
                                      SizedBox(
                                        width: 45,
                                        height: 45,
                                        child: FittedBox(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: getColor(
                                                    context,
                                                    ColorType.mapButtonShadow,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            child: FloatingActionButton(
                                              onPressed: () async {
                                                if (canVibrate &&
                                                    Platform.isIOS) {
                                                  await Haptics.vibrate(
                                                    HapticsType.light,
                                                  );
                                                }
                                                _showBusRoutesModal(
                                                  _busProviderRef!.routes,
                                                );
                                              },
                                              heroTag: 'routes_fab',
                                              elevation:
                                                  0, // handle shadow ourselves
                                              child: Icon(
                                                Icons.directions_bus,
                                                color: getColor(
                                                  context,
                                                  ColorType.mapButtonIcon,
                                                ),
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 12),

                                      // favorites
                                      SizedBox(
                                        width: 45,
                                        height: 45,
                                        child: FittedBox(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: getColor(
                                                    context,
                                                    ColorType.mapButtonShadow,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            child: FloatingActionButton(
                                              onPressed: () async {
                                                if (canVibrate &&
                                                    Platform.isIOS) {
                                                  await Haptics.vibrate(
                                                    HapticsType.light,
                                                  );
                                                }
                                                _showFavoritesSheet();
                                              },
                                              heroTag: 'favorites_fab',
                                              elevation: 0,
                                              child: Icon(
                                                Icons.favorite,
                                                color: getColor(
                                                  context,
                                                  ColorType.mapButtonIcon,
                                                ),
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 12),

                                      // search
                                      Expanded(
                                        // stretch width
                                        child: SizedBox(
                                          height: 45,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: getColor(
                                                    context,
                                                    ColorType.mapButtonShadow,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                if (canVibrate &&
                                                    Platform.isIOS) {
                                                  await Haptics.vibrate(
                                                    HapticsType.light,
                                                  );
                                                }
                                                _showSearchSheet();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                alignment: Alignment.centerLeft,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 13,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              icon: Icon(
                                                Icons.search_sharp,
                                                color: getColor(
                                                  context,
                                                  ColorType.mapButtonIcon,
                                                ),
                                                size: 28,
                                              ),
                                              label: Text(
                                                "where to?",
                                                style: TextStyle(
                                                  color: getColor(
                                                    context,
                                                    ColorType.mapButtonIcon,
                                                  ).withAlpha(214),
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
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
                    },
                  ),
                ),
        );
      },
    );
  }
}
