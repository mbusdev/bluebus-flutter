import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
// const String BACKEND_URL = 'https://mbus-310c2b44573c.herokuapp.com/mbus/api/v3'; 
const String BACKEND_URL = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://busapi.maizebus.com/mbus/api/v3'
);
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'https://www.efeakinci.host/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment("BACKEND_URL", defaultValue: "http://10.0.2.2:3000/mbus/api/v3/");
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://35.3.198.105:3000/mbus/api/v3');
//const String BACKEND_URL = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://35.2.102.249:3000/mbus/api/v3/');

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

final Uri contactURL = Uri.parse('https://www.maizebus.com/#/contact/');

// COLORS
const Color maizeBusDarkBlue = Color.fromARGB(255, 10, 0, 89);
const Color maizeBusYellow = Color.fromARGB(255, 255, 203, 45);
const Color maizeBusBlueDarkMode = Color.fromARGB(255, 80, 150, 210);
const Color maizeBusBlue = Color.fromARGB(255, 11, 83, 148);

enum ColorType {
  primary, secondary, opposite, background, grayed,

  mapButtonPrimary, mapButtonSecondary,
  mapButtonIcon, mapButtonShadow,

  highlighted, dim,

  shadow,
}

const Map<ColorType, Color> lightColors = {
  ColorType.primary: Colors.white,
  ColorType.secondary: Color.fromARGB(255, 226, 231, 236),
  ColorType.opposite: Colors.black,
  ColorType.background: Colors.white,
  ColorType.grayed: Color.fromARGB(255, 224, 224, 224),
  
  ColorType.mapButtonPrimary: maizeBusBlue, 
  ColorType.mapButtonSecondary: Color.fromARGB(204, 156, 196, 230),
  ColorType.mapButtonIcon: Colors.white,
  ColorType.mapButtonShadow: Color.fromARGB(77, 42, 133, 212), // 77 is 30% opacity

  ColorType.highlighted: Color.fromARGB(255, 120, 192, 255),
  ColorType.dim: Color.fromARGB(255, 229, 242, 255),

  ColorType.shadow: Color.fromARGB(95, 187, 187, 187)
};

const Map<ColorType, Color> darkColors = {
  ColorType.primary: Colors.black,
  ColorType.secondary: Color.fromARGB(255, 40, 54, 72),
  ColorType.opposite: Colors.white,
  ColorType.background: Color.fromARGB(255, 19, 34, 47),
  ColorType.grayed: Color.fromARGB(255, 5, 19, 32),

  ColorType.mapButtonPrimary: Color.fromARGB(204, 229, 242, 255),
  ColorType.mapButtonSecondary: Color.fromARGB(204, 106, 146, 181),
  ColorType.mapButtonIcon: Color.fromARGB(255, 29, 23, 84),
  ColorType.mapButtonShadow: Color.fromARGB(77, 30, 89, 141), // 77 is 30% opacity

  ColorType.highlighted: Color.fromARGB(255, 45, 151, 243),
  ColorType.dim: Color.fromARGB(255, 33, 71, 105),

  ColorType.shadow: Color.fromARGB(95, 68, 68, 68)
};

// returns true if the current theme is dark mode
bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

// Gets the Color value of a color name, depending on the current theme
// For example, to get the background color of a primary button on the map, use:
// getColor(context, ColorType.mapButtonPrimary)
// This will change depending on the current theme.
// All color types are in the ColorType enum.
Color getColor(BuildContext context, ColorType type) {
  return isDarkMode(context) ? darkColors[type]! : lightColors[type]!;
}

//Clipping path for the loading screen.
//the path has the bottom right corner replaced with a diagonal edge.
class TrapezoidClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width, 0); 
    path.lineTo(size.width - size.height, size.height); 
    path.lineTo(0, size.height);
    path.close(); 
    return path; 
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false; 
  }
}
class TrapezoidClipReversed extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(size.width, 0); 
    path.lineTo(size.width, size.height); 
    path.lineTo(0, size.height);
    path.lineTo(size.height, 0);
    path.close(); 
    return path; 
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false; 
  }
}

// THEMES
// These set default theme colors and styles for things such as text or buttons,
// depending on whether it is light or dark mode.
ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  fontFamily: 'Urbanist',

  // Default button themes
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: lightColors[ColorType.mapButtonPrimary],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(56),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: lightColors[ColorType.mapButtonPrimary],
    )
  ),

  dividerTheme: DividerThemeData(
    thickness: 2,
    color: lightColors[ColorType.dim],
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
  
  // Default button themes
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: darkColors[ColorType.mapButtonPrimary],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(56),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: darkColors[ColorType.mapButtonPrimary],
    )
  ),
  
  dividerTheme: DividerThemeData(
    thickness: 2,
    color: darkColors[ColorType.dim],
  ),
  
  // set default text color
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: Colors.white,
      fontFamily: 'Urbanist'
    )
  )
);

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

class Loadpoint {
  final String message;
  final int step;
  Loadpoint(this.message, this.step);
}