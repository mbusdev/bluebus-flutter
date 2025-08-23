import 'dart:async';
import 'dart:ui' as ui;
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
  Future<void>? _dataLoadingFuture;
  final _loadingMessageNotifier = ValueNotifier<String>('Initializing...');

  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(42.276463, -83.7374598);

  Set<Polyline> _displayedPolylines = {};
  Set<Marker> _displayedStopMarkers = {};
  Set<Marker> _displayedBusMarkers = {};
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
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    _loadingMessageNotifier.value = 'Contacting server...';
    // loading all this data in parallel
    await Future.wait([
      _loadCustomMarkers(),
      busProvider.loadRoutes(),
      _loadSelectedRoutes(),
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
    _loadingMessageNotifier.value = 'Starting app...';
    busProvider.startBusUpdates();
  
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
          destName: endLoc,                           // true = start changed, false = end changed
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
        );
      },
    );
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
              _showStopSheet(id, name, latLong!.latitude, latLong!.longitude);
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
                polylines: _displayedPolylines,
                markers: _displayedStopMarkers.union(_displayedBusMarkers),
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
                        ],
                      ),
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
                SizedBox(width: 30,),

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

                SizedBox(width: 30,),

                Column(
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
                          height: 16, width: 16,
                          child: CircularProgressIndicator(
                            color: const ui.Color.fromARGB(255, 11, 83, 148),
                          )
                        ),

                        SizedBox(width: 10,),

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
                          }
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          );
        }
      }
    );
  }
}
