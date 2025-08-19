import 'constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

List<Location> globalStopLocs = [];

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

  for (Location l in globalStopLocs){
    if (l.stopId == id){
      return (l.latlng);
    }
  }
}