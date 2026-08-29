import 'constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

List<Location> globalStopLocs = [];

double globalFollowDistanceThresholdMeters = 8.0;
int globalGpsUpdateDistanceFilterMeters = 5;

// the global app padding
// don't modify these here, instead use the helper function in map_screen.dart that sets these based on phone type and safe area insets
bool globallPaddingHasBeenSet = false;
double globalBottomPadding = 0;
double globalTopPadding = 0;
double globalLeftRightPadding = 0;

// the physical corner radius of the screen's bottom corners, loaded by map_screen.dart
// use this to keep rounded UI at the bottom of the screen concentric with the phone
double globalScreenBottomRadius = 0;

// helper function
String getStopNameFromID (String id){
  if (id == "VIRTUAL_DESTINATION"){
    return "destination";
  }

  for (Location l in globalStopLocs){
    if (l.stopId == id){
      return l.name;
    }
  }

  return id;
}

// helper function
LatLng? getLatLongFromStopID (String id){
  // TODO: use hashmap for faster lookup
  for (Location l in globalStopLocs){
    if (l.stopId == id){
      return (l.latlng);
    }
  }

  return null;
}

Location? getLocationFromID (String id) {
  // TODO: use hashmap for faster lookup
  for (Location l in globalStopLocs){
    if (l.stopId == id){
      return l;
    }
  }

  return null;
}