

import 'package:bluebus/models/bus_route_line.dart';
import 'package:latlong2/latlong.dart';

class BusInterpolator {
  List<BusRouteLine> routes = [];
  // Each BusRouteLine has a List<LatLng> called points.

  List<LatLng> large_segment = [];
  Map<double, LatLng> distanceElapsedToPoint = {};
    // i.e. a "0": LatLng(...) means that's the start point, "1.3": LatLng(...) means there's a change after 1.3 meters to a new LatLng segment point
  late double totalDistanceToTravel;

  late LatLng start;
  late LatLng end;

  BusInterpolator({
    required routes
  });

  void setEndpointCoords(LatLng start_in, LatLng end_in) {
    // TODO: Stop all animations here (if necessary, to avoid collisions)
    start = start_in;
    end = end_in;
  }

  void identifyPolylineSegment() {
    // Slices out the necessary portion of the polyline (i.e. the segments through which the bus travels to reach its end position)

    // Loop through the polylines to find:
    //    1. Distance from each polyline point to start
    //    2. Distance from each polyline point to end
    //    

    // How do we find the polyline point that is further away from the end position?
    // How do we find the polyline point that is further away from the start position?
    // How do we figure out which polyline points are on the same line? (i.e. a path might travel the same road twice, once in each direction. How can we make sure the polyline segment we've chosen connects the start and end points? Do we need a length limit when searching?)
    
    // Now save the applicable polyline segment in the segment varaible
    
    // FUTURE: Maybe save these in a 
  }

  // TODO: Write methods to set animation length and framerate

  void computeSegmentDistance() {
    // Set totalDistanceToTravelled to 0

    // Start from wherever the bus is to the SECOND point in the segment.
    // For each segment:
    //    1. Calculate the distance between the end point and start point
    //    2. Save this distance in a map/JSON object
    //    3. Also contribute to the total distance to travel variable
  }

  // Also write a method to comp

  LatLng interpolateBusPosition(double elapsedDistance) {
    // 1. Figure out which polyline segment the bus is currently in
    //    Loop through the distanceElapsedToPoint map until we find a distance that is GREATER than the elapsedDistance (if none is found, place the bus at the end point and return?)
    //    Also store the point immediately BEFORE the point just found. This will isolate two points, and the bus must be between them. (We'll call this the isolated segment)
    double elapsed_distance_in_isolated_segment;
    // Find the elapsed distance in the isolated segment
    // 2. Calculate the position along that segment: 
    //    percent_travelled_through_isolated_segment = (elapsed_distance_in_isolated_segment) / total_distance_of_isolated_segment
    // 3. Multiply segment_width * percent_travelled_through_isolated_segment and segment_height * percent_travelled_through_isolated_segment, and add the isolated segment start point values to get back an X and Y we can plot on the map!!

    return LatLng(0,0);
  }


}


// FUTURE: If the app is reopened, immediately throw out a request for new bus positions and update them without animation