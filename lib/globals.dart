import 'constants.dart';

List<Location> globalStopLocs = [];

// helper function
String getStopNameFromID (String id){
  for (Location l in globalStopLocs){
    if (l.stopId == id){
      return l.name;
    }
  }

  return id;
}