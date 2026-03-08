// Import necessary Flutter packages
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'services/bus_repository.dart';
import 'providers/bus_provider.dart';
import 'providers/theme_provider.dart';

// This function initializes the Flutter app and runs the MainApp widget
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initPlugin();
  await IncomingBusReminderService.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BusProvider(repository: BusRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()
        )
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
      child: Consumer<ThemeProvider>( // rebuilds when ThemeProvider changes
        builder: ( 
          context, themeObj, child) => MaterialApp(
          //showPerformanceOverlay: true,
          // Remove the debug banner
          debugShowCheckedModeBanner: false,
          title: 'MaizeBus',
          theme: themeObj.getThemeData(), // gets ThemeData object of current theme

          // Show onboarding on first run (terms acceptance). OnboardingDecider
          // will display the welcome + terms flow if needed, otherwise the map.
          home: const OnboardingDecider(),
        )
      )
    );
  }
}
