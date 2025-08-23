// Import necessary Flutter packages
import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
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
      title: 'MaizeBus',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: maizeBusDarkBlue,
        ),
        useMaterial3: true,
        fontFamily: 'Urbanist',
        scaffoldBackgroundColor: Colors.white,
      ),

      // Show onboarding on first run (terms acceptance). OnboardingDecider
      // will display the welcome + terms flow if needed, otherwise the map.
      home: const OnboardingDecider(),
    );
  }
}
