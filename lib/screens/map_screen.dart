import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_selector_modal.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';
import '../providers/bus_provider.dart';
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
      if (!_routePolylines.containsKey(r.routeId)) {
        _routePolylines[r.routeId] = Polyline(
          polylineId: PolylineId(r.routeId + r.points.hashCode.toString()),
          points: r.points,
          color: Colors.blue,
          width: 4,
        );
      }
      if (!_routeStopMarkers.containsKey(r.routeId)) {
        _routeStopMarkers[r.routeId] = r.stops
            .map((stop) => Marker(
                  markerId: MarkerId('stop_${stop.id}'),
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
      final polyline = _routePolylines[routeId];
      if (polyline != null) selectedPolylines.add(polyline);
      final stops = _routeStopMarkers[routeId];
      if (stops != null) selectedStopMarkers.addAll(stops);
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
        .map((bus) => Marker(
              markerId: MarkerId('bus_${bus.id}'),
              position: bus.position,
              icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
              rotation: bus.heading,
              anchor: const Offset(0.5, 0.5), // Center the icon on the position
              infoWindow: InfoWindow(title: 'Bus ${bus.id}'),
            ))
        .toSet();
    setState(() {
      _displayedBusMarkers = selectedBusMarkers;
    });
  }

  void _refreshAllMarkers() {
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    _updateDisplayedRoutes();
    _updateDisplayedBuses(busProvider.buses);
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

  Future<void> _centerOnUserLocation() async {
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

      // Get the user's current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Animate the map camera to the user's location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
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
    return Scaffold(
      body: Stack(
        children: [
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
          Positioned(
            top: 100,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _centerOnUserLocation,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.my_location,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBusRoutesModal(busProvider.routes),
        backgroundColor: Colors.blue,
        child: const Icon(
          Icons.directions_bus,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
} 