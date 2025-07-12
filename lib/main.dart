// Import necessary Flutter packages
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// This function initializes the Flutter app and runs the MainApp widget
void main() {
  runApp(const MainApp());
}

// Main application widget that manages the Google Maps interface
// This is a stateful widget because we need to maintain the map controller
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Remove the debug banner for a cleaner look
      debugShowCheckedModeBanner: false,
      title: 'BlueBus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

// Separate widget for the map screen
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// State class for MapScreen that handles the Google Maps functionality
class _MapScreenState extends State<MapScreen> {
  // Controller for the Google Map widget
  // This allows us to programmatically control the map (zoom, pan, etc.)
  GoogleMapController? _mapController;

  // Default center coordinates for the map
  // These coordinates point to a location (you can change this to your desired location)
  static const LatLng _defaultCenter = LatLng(42.276463, -83.7374598);

  // List to store selected bus routes
  final Set<String> _selectedRoutes = <String>{};

  // Sample bus routes
  // TODO: Add descriptions to the routes?
  final List<Map<String, String>> _busRoutes = [
    {'id': '1', 'name': 'Commuter North'}, // 'description': ''
    {'id': '2', 'name': 'Commuter South'}, // 'description': ''
    {'id': '3', 'name': 'Crisler Express'}, // 'description': ''
    {'id': '4', 'name': 'Med Express'}, // 'description': ''
    {'id': '5', 'name': 'North-East Shuttle'}, // 'description': ''
    {'id': '6', 'name': 'Northwood'}, // 'description': ''
    {'id': '7', 'name': 'Wall Street-NIB'}, // 'description': ''
    {'id': '8', 'name': 'Wall Street Express'}, // 'description': ''
  ];

  // Callback function that's triggered when the Google Map is created
  // This is where we store the map controller for later use
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // Function to center map on user's current location
  // This method handles location permissions, gets the user's current position,
  // and animates the map camera to that location
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
        // Request permission if not already granted
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

      // Handle permanently denied permissions
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
              zoom: 15.0, // Zoom level suitable for city/neighborhood view
            ),
          ),
        );
      }
    } catch (e) {
      // Handle any errors that occur during the location process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to show the bus routes selection modal
  // This creates a bottom sheet modal that allows users to select/deselect bus routes
  void _showBusRoutesModal() {
    // Create a temporary set for the modal selection to avoid modifying the main state
    // until the user confirms their selection
    final Set<String> tempSelectedRoutes = Set<String>.from(_selectedRoutes);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the modal cover most of the screen
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header section with title and close button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Bus Routes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable list of bus routes with selection functionality
                  Expanded(
                    child: ListView.builder(
                      itemCount: _busRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _busRoutes[index];
                        final isSelected = tempSelectedRoutes.contains(route['id']);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            // Bus icon that changes color based on selection state
                            leading: Icon(
                              Icons.directions_bus,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              route['name']!,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            // TODO: uncomment this if we want to have descriptions
                            // subtitle: Text(route['description']!), // Commented out to give more space to route names

                            // Checkbox for selection - can be tapped to toggle
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    tempSelectedRoutes.add(route['id']!);
                                  } else {
                                    tempSelectedRoutes.remove(route['id']!);
                                  }
                                });
                              },
                            ),
                            // Allow tapping anywhere on the tile to toggle selection
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelectedRoutes.remove(route['id']!);
                                } else {
                                  tempSelectedRoutes.add(route['id']!);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  // Apply button to confirm selections and close modal
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Update the main state with the temporary selections
                        setState(() {
                          _selectedRoutes.clear();
                          _selectedRoutes.addAll(tempSelectedRoutes);
                        });
                        Navigator.pop(context);
                        // TODO: Display selected routes on the map
                        _showSelectedRoutes();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Apply Selection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Function to show selected routes (placeholder for now)
  // This method provides user feedback about their route selections
  // In the future, this will be expanded to actually display routes on the map
  void _showSelectedRoutes() {
    if (_selectedRoutes.isEmpty) {
      // Show warning when no routes are selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routes selected'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Show success message with count of selected routes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${_selectedRoutes.length} route(s)'),
          backgroundColor: Colors.green,
        ),
      );
      // TODO: Add logic to display routes on the map
      // For now, just print the selected routes to console for debugging
      print('Selected routes: $_selectedRoutes');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main body contains a stack with the map and custom controls
      body: Stack(
        children: [
          // Google Map widget that displays the interactive map
          GoogleMap(
            // Callback when map is created - stores the controller for later use
            onMapCreated: _onMapCreated,
            // Initial camera position and zoom level
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 15.0, // Zoom level (1-20, where 1 is world view, 20 is building level)
            ),
            // Enable user interaction with the map
            myLocationEnabled: true, // Shows user's current location as a blue dot
            myLocationButtonEnabled: false, // Disable default location button (we have our own)
            // Enable basic map controls
            zoomControlsEnabled: true, // Shows zoom in/out buttons
            mapToolbarEnabled: true, // Shows map toolbar with additional options
          ),
          // Custom location button positioned higher on the right side
          // This allows users to quickly center the map on their current location
          Positioned(
            top: 100, // Position higher than the default to avoid conflicts
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
      // Floating action button to open bus routes selection modal
      // Positioned on the left side for easy thumb access
      floatingActionButton: FloatingActionButton(
        onPressed: _showBusRoutesModal,
        backgroundColor: Colors.blue,
        child: const Icon(
          Icons.directions_bus,
          color: Colors.white,
        ),
      ),
      // Floating action button location (positioned on the left side)
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  @override
  void dispose() {
    // Clean up the map controller when the widget is disposed
    _mapController?.dispose();
    super.dispose();
  }
}