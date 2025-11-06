import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// UPDATE WHEN RELAUNCH
final String currentVersion = '1.0.2';

bool isCurrentVersionEqualOrHigher(String otherVersion) {
  final List<int> currentParts =
      currentVersion.split('.').map(int.parse).toList();
  final List<int> otherParts =
      otherVersion.split('.').map(int.parse).toList();

  final int length =
      (currentParts.length < otherParts.length) ? currentParts.length : otherParts.length;

  for (int i = 0; i < length; i++) {
    if (currentParts[i] > otherParts[i]) {
      return true;
    }
    if (currentParts[i] < otherParts[i]) {
      return false;
    }
  }

  return currentParts.length >= otherParts.length;
}

// Backend url for the api
const String BACKEND_URL = 'https://mbus-310c2b44573c.herokuapp.com/mbus/api/v3'; 
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://www.efeakinci.host/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment("BACKEND_URL", defaultValue: "http://10.0.2.2:3000/mbus/api/v3/");
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://192.168.0.247:3000/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000/mbus/api/v3/');

List<Map<String, String>> globalAvailableRoutes = [];

// Mapping from route code to full name
const Map<String, String> fallback_code_to_name = {
  'CN': 'Commuter North',
  'CSX': 'Crisler Express',
  'MX': 'Med Express',
  'WS': 'Wall Street-NIB',
  'WX': 'Wall Street Express',
  'CS': 'Commuter South',
  'NW': 'Northwood',
  'NES': 'North-East Shuttle',
};

String getPrettyRouteName(String code) {
  for (Map<String, String> route in globalAvailableRoutes) {
    if (route['id'] == code) {
      return route['name'] ?? route['id']!;
    }
  }

  // fallback
  final name = fallback_code_to_name[code];
  return name != null ? name : code;
}

// COLORS
const Color maizeBusDarkBlue = Color.fromARGB(255, 10, 0, 89);
const Color maizeBusYellow = Color.fromARGB(255, 241, 194, 50);
const Color maizeBusBlue = Color.fromARGB(255, 11, 83, 148);

const Map<String, Color> lightColors = {
  'background': Colors.white,
  'mapButtonPrimary': Color.fromARGB(204, 29, 23, 84), // 204 is 80% opacity
  'mapButtonSecondary': Color.fromARGB(204, 156, 196, 230),
  'buttonSelected': Color.fromARGB(255, 120, 192, 255),
  'button': Color.fromARGB(255, 229, 242, 255),
};

const Map<String, Color> darkColors = {
  'background': Color.fromARGB(255, 19, 34, 47),
  'mapButtonPrimary': Color.fromARGB(217, 229, 242, 255), // 217 is 85% opacity
  'mapButtonSecondary': Color.fromARGB(204, 106, 146, 181),
  'buttonSelected': Color.fromARGB(255, 45, 151, 243),
  'button': Color.fromARGB(255, 33, 71, 105)
};

// THEMES
ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Urbanist',
  
  // Usage example
  // color: Theme.of(context).primaryColorLight
  primaryColorLight: Colors.white,
  primaryColorDark: Colors.black,
  
  // Use for background colors
  canvasColor: lightColors['background'],

  // Gray box color and shadow color
  // cardColor: Color.fromARGB(255, 235, 235, 235),
  cardColor: lightColors['button'],
  shadowColor: Color.fromARGB(95, 187, 187, 187),

  // Default button colors
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: lightColors['mapButtonPrimary'],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(56),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: lightColors['mapButtonPrimary'],
    )
  ),

  // set default text color
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: Colors.black,
      fontFamily: 'Urbanist'
    )
  )
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Urbanist',
  
  // Usage example
  // color: Theme.of(context).primaryColorLight
  primaryColorLight: Colors.black,
  primaryColorDark: Colors.white,
  
  // Use for background colors
  canvasColor: darkColors['background'],
  
  // Gray box color and shadow color
  // cardColor: Color.fromARGB(255, 35, 35, 35),
  cardColor: darkColors['button'],
  shadowColor: Color.fromARGB(95, 68, 68, 68),

  // Default button themes
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: darkColors['mapButtonPrimary'],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(56),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: darkColors['mapButtonPrimary'],
    )
  ),
  
  // set default text color
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: Colors.white,
      fontFamily: 'Urbanist'
    )
  )
);

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color getColor(BuildContext context, String type) {
  return isDarkMode(context) ? darkColors[type]! : lightColors[type]!;
}

//data types
class Location {
  final String name;
  final String abbrev;
  final List<String> aliases;

  final String? stopId;
  final LatLng? latlng;

  final bool isBusStop;

  Location(
    this.name,
    this.abbrev,
    List<String> aliases,
    this.isBusStop, {
    this.stopId,
    this.latlng,
  }) : aliases = aliases;
}

class StartupDataHolder {
  String version;
  String updateTitle;
  String updateMessage;
  String persistantMessageTitle;
  String persistantMessage;
  StartupDataHolder(this.version, this.updateTitle, this.updateMessage, this.persistantMessageTitle, this.persistantMessage);
}
