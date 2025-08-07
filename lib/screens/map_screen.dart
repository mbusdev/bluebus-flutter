import 'dart:async';
import 'dart:ui' as ui;
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_selector_modal.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
import '../providers/bus_provider.dart';
import '../services/route_color_service.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import '../constants.dart';
import '../widgets/journey_search_panel.dart';

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
  final Set<String> _selectedRoutes = <String>{};
  List<Map<String, String>> _availableRoutes = [];
  Map<String, String> _routeIdToName = {};

  // Custom marker icons
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _stopIcon;

  // Memoization caches
  final Map<String, Polyline> _routePolylines = {};
  final Map<String, Set<Marker>> _routeStopMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      busProvider.loadRoutes().then((_) {
        _updateAvailableRoutes(busProvider.routes);
        _cacheRouteOverlays(busProvider.routes);
        _updateDisplayedRoutes();
        busProvider.loadBuses();
        busProvider.startBusUpdates();
      });
    });
  }

  Future<void> _loadCustomMarkers() async {
    try {
      // Load and resize bus icon
      final busBytes = await rootBundle.load('assets/bus_blue.png');
      final busCodec = await ui.instantiateImageCodec(
        busBytes.buffer.asUint8List(),
        targetWidth: 150,
        targetHeight: 250,
      );
      final busFrame = await busCodec.getNextFrame();
      final busData = await busFrame.image.toByteData(format: ui.ImageByteFormat.png);
      _busIcon = BitmapDescriptor.fromBytes(busData!.buffer.asUint8List());

      // Load and resize stop icon
      final stopBytes = await rootBundle.load('assets/bus_stop.png');
      final stopCodec = await ui.instantiateImageCodec(
        stopBytes.buffer.asUint8List(),
        targetWidth: 90,
        targetHeight: 90,
      );
      final stopFrame = await stopCodec.getNextFrame();
      final stopData = await stopFrame.image.toByteData(format: ui.ImageByteFormat.png);
      _stopIcon = BitmapDescriptor.fromBytes(stopData!.buffer.asUint8List());
      
      // Refresh markers with new icons
      if (mounted) {
        _refreshAllMarkers();
      }
    } catch (e) {
      // Fallback to default markers if custom loading fails
      _busIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      _stopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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
        final name = getPrettyRouteName(r.routeId);
        routeIdToName[r.routeId] = name;
      }
    }
    setState(() {
      _routeIdToName = routeIdToName;
      _availableRoutes = routeIdToName.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
    });
  }

  void _cacheRouteOverlays(List<BusRouteLine> routes) {
    for (final r in routes) {
      // Create unique key for each route variant
      final routeKey = '${r.routeId}_${r.points.hashCode}';
      final routeColor = RouteColorService.getRouteColor(r.routeId);
      
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
            .map((stop) => Marker(
                  markerId: MarkerId('stop_${stop.id}_${r.points.hashCode}'),
                  position: stop.location,
                  icon: _stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(title: stop.name),
                ))
            .toSet();
      }
    }
  }
  


  void _updateDisplayedRoutes() {
    final selectedPolylines = <Polyline>{};
    final selectedStopMarkers = <Marker>{};
    
    for (final routeId in _selectedRoutes) {
      // Find all variants of this route
      final routeVariants = _routePolylines.keys.where((key) => key.startsWith('${routeId}_'));
      
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
    _updateDisplayedBuses(Provider.of<BusProvider>(context, listen: false).buses);
  }

  void _updateDisplayedBuses(List<Bus> allBuses) {
    final selectedBusMarkers = allBuses
        .where((bus) => _selectedRoutes.contains(bus.routeId))
        .map((bus) {
          final routeColor = RouteColorService.getRouteColor(bus.routeId);
          return Marker(
            markerId: MarkerId('bus_${bus.id}'),
            position: bus.position,
            icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(_colorToHue(routeColor)),
            rotation: bus.heading,
            anchor: const Offset(0.5, 0.5), // Center the icon on the position
            infoWindow: InfoWindow(
              title: 'Bus ${bus.id}',
              snippet: 'Route ${bus.routeId}',
            ),
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
    _updateDisplayedRoutes();
    _updateDisplayedBuses(busProvider.buses);
  }

  void _refreshCachedStopMarkers() {
    // Clear cached stop markers so they'll be recreated with the new icons
    _routeStopMarkers.clear();
    // Re-cache all route overlays with the new icons
    _cacheRouteOverlays(Provider.of<BusProvider>(context, listen: false).routes);
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
          onApply: (Set<String> newSelection) {
            if (newSelection.difference(_selectedRoutes).isNotEmpty || _selectedRoutes.difference(newSelection).isNotEmpty) {
              setState(() {
                _selectedRoutes.clear();
                _selectedRoutes.addAll(newSelection);
              });
              _updateDisplayedRoutes();
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
        // Pass the callback function here
        return SearchSheet(
          // Define what happens when a location is selected in the sheet
          onSearch: (Location location) {

            final searchCoordinates = location.latlng;

            // null-proofing
            if (searchCoordinates != null) {
              _centerOnLocation(false, searchCoordinates.latitude, searchCoordinates.longitude);
              _showBuildingSheet(location);
            } else {
              print("Error: The selected location '${location.name}' has no coordinates.");
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
        return BuildingSheet(building: place,);
      },
    );
  }

  Future<void> _centerOnLocation(bool userLocation, [double lat = 0, double long = 0] ) async {
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
      Position position = Position(longitude: long, latitude: lat, timestamp: DateTime.now(), accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);

      if (userLocation){
        // Get the user's current position with high accuracy
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      // Animate the map camera to the user's location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: userLocation? 15.0 : 17.0,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (busProvider.error != null) {
      return Scaffold(
        body: Center(child: Text(busProvider.error!)),
      );
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
                        onPressed: (){
                          _centerOnLocation(true);
                        },
                        backgroundColor: const ui.Color.fromARGB(176, 255, 255, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(56)
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
                            onPressed: () => _showBusRoutesModal(busProvider.routes),
                            backgroundColor: maizeBusDarkBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(56)
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
      
                      SizedBox(
                        width: 15,
                      ),
                  
                      // favorites
                      SizedBox(
                        width: 55,
                        height: 55,
                        child: FittedBox(
                          child: FloatingActionButton(
                            onPressed: () => print("hi"),
                            backgroundColor: maizeBusDarkBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(56)
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
                            backgroundColor: maizeBusDarkBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(56)
                            ),
                            child: const Icon(
                              Icons.search,
                              size: 35,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      );
  }
} 