// Import necessary Flutter packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/bus_repository.dart';
import 'providers/bus_provider.dart';
import 'services/route_color_service.dart';

// This function initializes the Flutter app and runs the MainApp widget
void main() async {
  await RouteColorService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BusProvider(repository: BusRepository()),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

// Main application widget that manages the Google Maps interface
// This is a stateful widget because we need to maintain the map controller
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Remove the debug banner
      debugShowCheckedModeBanner: false,
      title: 'BlueBus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Urbanist'
      ),
      
      home: const MapScreen(),
    );
  }
}