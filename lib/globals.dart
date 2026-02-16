import 'constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

List<Location> globalStopLocs = [];

// the global app padding
// don't modify these here, instead use the helper function in map_screen.dart that sets these based on phone type and safe area insets
double globalBottomPadding = 0;
double globalTopPadding = 0;
double globalLeftRightPadding = 0;

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