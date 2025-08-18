import 'constants.dart';

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