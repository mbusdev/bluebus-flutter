import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// UPDATE WHEN RELAUNCH
final String currentVersion = '2.0.0';

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

final _whitespacePattern = RegExp(r'\s+');

String normalizeStopName(String rawStopName) {
  // Remove random characters (add them to list if needed), collapse whitespace to a single space, and trim edges.
  return rawStopName.replaceAll('%', '').replaceAll(_whitespacePattern, ' ').trim();
}

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
  primary, secondary, opposite, background, backgroundGradientStart,

  mapButtonPrimary, mapButtonSecondary,
  mapButtonIcon, mapButtonShadow,

  inputBackground, inputText,

  highlighted, dim, error,
  shadow,
  
  sliderBackground, sliderButton,

  // info card colors (in route selector, favorites sheet, etc.)
  infoCardColor, infoCardHighlighted,

  // all the buttons except for the main map buttons
  importantButtonBackground, importantButtonText,
  secondaryButtonBackground, secondaryButtonText,
}

const Map<ColorType, Color> lightColors = {
  ColorType.primary: Colors.white,
  ColorType.secondary: Color.fromARGB(255, 226, 231, 236),
  ColorType.opposite: Colors.black,
  ColorType.background: Colors.white,
  ColorType.backgroundGradientStart: Color.fromARGB(0, 255, 255, 255), // same as background but transparent
  
  ColorType.mapButtonPrimary: maizeBusBlue, 
  ColorType.mapButtonSecondary: Color.fromARGB(190, 255, 255, 255),
  ColorType.mapButtonIcon: Colors.white,
  ColorType.mapButtonShadow: Color.fromARGB(77, 133, 133, 133), 

  ColorType.highlighted: Color.fromARGB(255, 120, 192, 255),
  ColorType.dim: Color.fromARGB(255, 215, 228, 241),
  ColorType.error: Color.fromARGB(255, 242, 41, 41),

  ColorType.shadow: Color.fromARGB(95, 187, 187, 187),
  
  ColorType.sliderButton: Colors.white,
  ColorType.sliderBackground: Color.fromARGB(255, 200, 228, 255), 

  ColorType.infoCardColor: Color.fromARGB(255, 255, 255, 255), 
  ColorType.infoCardHighlighted: Color.fromARGB(255, 200, 228, 255),  

  ColorType.inputBackground: Color.fromARGB(255, 227, 227, 227),
  ColorType.inputText: Colors.black,

  ColorType.importantButtonBackground: maizeBusBlue,
  ColorType.importantButtonText: Colors.white,
  ColorType.secondaryButtonBackground: Color.fromARGB(255, 215, 228, 241),
  ColorType.secondaryButtonText: maizeBusBlue,
};

const Map<ColorType, Color> darkColors = {
  ColorType.primary: Colors.black,
  ColorType.secondary: Color.fromARGB(255, 40, 54, 72),
  ColorType.opposite: Colors.white,
  ColorType.background: Color.fromARGB(255, 32, 33, 34),
  ColorType.backgroundGradientStart: Color.fromARGB(0, 32, 33, 34), // same as background but transparent

  ColorType.mapButtonPrimary: Color.fromARGB(255, 255, 255, 255),
  ColorType.mapButtonSecondary: Color.fromARGB(187, 104, 104, 134),
  ColorType.mapButtonIcon: maizeBusBlue,
  ColorType.mapButtonShadow: Color.fromARGB(95, 68, 68, 68), 

  ColorType.highlighted: Color.fromARGB(255, 49, 129, 199),
  ColorType.dim: Color.fromARGB(255, 47, 54, 60),
  ColorType.error: Color.fromARGB(255, 255, 114, 114),

  ColorType.shadow: Color.fromARGB(95, 68, 68, 68),
  
  ColorType.sliderButton: Color.fromARGB(255, 32, 33, 34),
  ColorType.sliderBackground: Color.fromARGB(255, 33, 71, 105),

  ColorType.infoCardColor: Color.fromARGB(255, 47, 54, 60),
  ColorType.infoCardHighlighted: Color.fromARGB(255, 33, 71, 105),

  ColorType.inputBackground:Color.fromARGB(255, 47, 54, 60),
  ColorType.inputText: Colors.white,

  ColorType.importantButtonBackground: Color.fromARGB(255, 49, 129, 199),
  ColorType.importantButtonText: Colors.white,
  ColorType.secondaryButtonBackground: Color.fromARGB(255, 47, 54, 60),
  ColorType.secondaryButtonText: Color.fromARGB(255, 49, 129, 199),
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

BoxShadow infoCardShadowLight = BoxShadow(
  color: Color.fromARGB(80, 38, 114, 181),
  blurRadius: 5,
  spreadRadius: 1,
  offset: Offset(0, 1),
);

BoxShadow infoCardShadowDark = BoxShadow(
  color: Color.fromARGB(91, 0, 0, 0),
  blurRadius: 5,
  offset: Offset(0, 3),
);

// Gets the correct shadow depending on 
BoxShadow getInfoCardShadow(BuildContext context) {
  return isDarkMode(context) ? infoCardShadowDark : infoCardShadowLight;
}

Color getGradientLerpColor(BuildContext context, double percentage) {
  if (percentage == 1) {
    return getColor(context, ColorType.background);
  } else if (percentage == 0) {
    return getColor(context, ColorType.backgroundGradientStart); // Transparent
  }

  return Color.lerp(
    getColor(context, ColorType.backgroundGradientStart),
    getColor(context, ColorType.background),
    percentage
  )!;
}

LinearGradient getStopHeroImageGradient(BuildContext context) {
  // A slightly smoother gradient than sRGB 
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      getGradientLerpColor(context, 0),
      getGradientLerpColor(context, 0.15),
      getGradientLerpColor(context, 0.5),
      getGradientLerpColor(context, 0.75),
      getGradientLerpColor(context, 1)
    ],
    // original stops by Isaac
    // stops: [0.6, 0.65, 0.74, 0.85, 1]

    // adjusted stops by Ishan - using the same ratios but less tall
    stops: [0.67, 0.71, 0.79, 0.88, 1]
  );
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

// TEXT
enum TextType {
  modalHeader, logo, bold, normal, small, sectionHeader    
}

TextStyle getTextStyle(TextType type, Color? color) {
  double size, height;
  FontWeight weight;
  switch (type) {
    case TextType.modalHeader:
      size = 30;
      weight = FontWeight.w700;
      height = 30;
    case TextType.logo:
      size = 30;
      weight = FontWeight.w800;
      height = 30;
    case TextType.bold:
      size = 16;
      weight = FontWeight.w700;
      height = 20;
    case TextType.normal:
      size = 16;
      weight = FontWeight.w400;
      height = 20;
    case TextType.small:
      size = 14;
      weight = FontWeight.w400;
      height = 20;
    case TextType.sectionHeader:
      size = 22;
      weight = FontWeight.w700;
      height = 26.4;
  }
  return TextStyle(color: color, fontFamily: 'Urbanist', fontSize: size, fontWeight: weight, height: height / size);
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

// location with arrival time attached
// used for flow in journey
class ArrivalTimeLocation extends Location {
  final String arrivalTime;

  ArrivalTimeLocation(
    this.arrivalTime, 
    Location loc,
  ) : super(
    loc.name,
    loc.abbrev,
    loc.aliases,
    loc.isBusStop,
    stopId: loc.stopId,
    latlng: loc.latlng,
  );
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

const SheetBoxShadow = BoxShadow(
  color: Color.fromRGBO(0, 0, 0, 0.2),
  offset: const Offset(
    0.0,
    0.0,
  ),
  blurRadius: 100.0,
  spreadRadius: 40.0,
);
