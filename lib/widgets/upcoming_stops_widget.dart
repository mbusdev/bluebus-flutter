import 'dart:math';

import 'package:bluebus/constants.dart';
import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bus_stop.dart';

final Map<String, String> KEY_STOPS = {
  // Key stops are shown larger in the list of upcoming stops for each bus.
  //     You can also rename them here!

  // Key stops were chosen by whether they met one of the following criteria
  //  * Was a major landmark (i.e. large shopping malls, Walmart/Meijer, Michigan Stadium, transit center, Amtrak, etc)
  //  * Was the end/beginning of a route
  //  * Was a stop unique to that route or a small set of routes (e.g. Oxford Housing)

  "C250": "Central Campus Transit Center", // South side CCTC
  "C251": "Central Campus Transit Center", // North side CCTC
  "N551": "Pierpont Commons", // Murfin Inbound, to Central Campus
  "N553": "Pierpont Commons", // Bonisteel Inbound, to central campus
  "N552": "Pierpont Commons", // Art & Architecture: Eastbound to FXB
  "N550": "Pierpont Commons", // Murfin Outbound, to Bursley
  "N407": "Bursley Hall", // Bursley Hall Inbound (Westbound)
  "N408": "Bursley Hall", // Bursley Hall Outbound (Eastbound)
  "N406": "FXB Building", // FXB Outbound (Northbound)
  "N405": "FXB Building", // FXB Inbound (Southbound)
  "S003": "Crisler Center/Michigan Stadium", // Transportation Gate (Northbound)
  "S002": "Crisler Center/Michigan Stadium", // Crisler Center Lot SC-5 (Southbound)
  "C206": "Oxford Housing", // Self-explanatory
  "M323": "Wall Street Parking Structure",
  "N422": "Northwood Fire Station", // "Top" of Northwood route
  "N437": "Northwood V",

  "1285": "Central Campus Transit Center", // TheRide stop for CCTC, southbound. Route 62, 23, 64
  "1776": "Central Campus Transit Center", // TheRide stop for CCTC, northbound. Route 23, 104, 63, 64

  // Blake transit center stops
  "140": "Blake Transit Center",
  "142": "Blake Transit Center",
  "143": "Blake Transit Center",
  "144": "Blake Transit Center",
  "145": "Blake Transit Center",
  "137": "Blake Transit Center",
  "138": "Blake Transit Center",
  "145": "Blake Transit Center",
  "1150": "Blake Transit Center",
  "2262": "Blake Transit Center",

  // Ypsilanti Transit Center stops
  "130": "Ypsilanti Transit Center",
  "131": "Ypsilanti Transit Center",
  "132": "Ypsilanti Transit Center",
  "133": "Ypsilanti Transit Center",
  "135": "Ypsilanti Transit Center",
  "146": "Ypsilanti Transit Center",

  "1564": "VA Medical Center",
  "267": "Trinity Health - Ann Arbor Hospital",
  "266": "Washtenaw Community College - Student Ctr",
  "2250": "Washtenaw Community College - Service Dr",
  "2250": "Washtenaw Community College - South Side",
  "1944": "Briarwood Mall - Main Stop", // Route 6, 67
  "420": "Meijer - Carpenter Rd",
  "959": "Roundtree Place Shopping Center",
  "952": "Roundtree Place Shopping Center",
  "330": "Manchester Park",
  "1350": "Traver Village Shopping Center", // Route 22, 23, 65
  "1455": "Green Rd Park and Ride", // Route 65, 66

  "1591": "Meijer - Saline South",

  "2160": "Scio Ridge + Sudburry",
  "2161": "Scio Ridge + Chamberlain",

  "1199": "Pauline + South Maple", // Route 27, 28
  "659": "Michigan Stadium", // Route 25, 29

  "681": "Westgate Shopping Center", // Route 28
  "710": "Westgate Shopping Center",
  "704": "Westgate Shopping Center",

  "1271": "Meijer - Jackson Road", // Route 30

  "1880": "Skyline High School", // Route 61

  "1492": "Rudolf Steiner School", // Route 33?
  "795": "Holyoke + Newport", // Route 33

  "1885": "Amtrak Station", // Route 33

  "1759": "Miller Rd Park + Ride", // Route 34, 61

  "1936": "Aldi Grocery",

  "1642": "Tyler + Nash", // Route 44

  "2196": "Harbour Cove Tennis Court", // Route 46

  "2195": "Arbor Preparatory High School", // Route 46

  "1977": "Kroger - Paint Creek", // Route 46
  "1955": "Kroger - Paint Creek", // Route 46

  "1640": "Ypsilanti Township Civic Center", // Route 46
  "2212": "Ypsilanti Township Civic Center", // Route 46

  "1019": "Harry + Grove", // Route 45

  "2156": "Holmes + Ridge", // Route 43, 68
  "983": "Ridge + Holmes", // Route 42, 43

  "1433": "MacArthur + Harris", // Route 42

  "1293": "Wolverine Tower (Briarwood)", // Route 62
  "2235": "U-M Tennis and Gymnastics", // Route 62
  "1750": "U-M Tennis and Gymnastics", // Route 62

  "582": "Pioneer High School", // Route 25, 26, 29, 64

  "1697": "Dhu Varren Foodgatherers", // Route 63

  "190": "Kellogg Eye Center", // Route 23, 63
  "235": "Kellogg Eye Center", // Route 23, 63

  "2169": "Roundtree Place Shopping Ctr", // Route 47

  "419": "Meijer - Carpenter Rd", // Route 66, 5

  "1499": "Service Dr. + Emerick", // Route 68
  "2156": "Holmes + Ridge",
  "983": "Holmes + Ridge",

  // TODO: Add other important stops for buses
};



// TODO: Add a heart if a stop is favorited!

String futureTime(String minutesInFuture) {
  int min = int.parse(minutesInFuture);
  DateTime now = DateTime.now();
  DateTime futureTime = now.add(Duration(minutes: min));
  return DateFormat('h:mm a').format(futureTime);
}

bool isRide(String? s) {
  if (s != null && int.tryParse(s) != null) {
    // busID is numeric, so it's a ride bus
    return true;
  } 
  return false;
}

// TODO: Make KEY_STOPS an API call!

const Color UPCOMING_STOP_COLOR = Color.fromARGB(255, 85, 119, 130);
const Color BIG_STOP_BORDER_COLOR_LIGHTMODE = Color.fromARGB(255, 91, 96, 100);
const Color BIG_STOP_BORDER_COLOR_DARKMODE = Color.fromARGB(255, 255, 255, 255);
const Color BIG_STOP_FILL_COLOR_LIGHTMODE = Colors.white;
// Color BIG_STOP_FILL_COLOR_DARKMODE = darkColors[ColorType.background] ?? Colors.black;
const Color BIG_STOP_FILL_COLOR_DARKMODE = Color.fromARGB(255, 93, 112, 129);

const int LINE_CONNECTED = 1;
const int LINE_DISCONNECTED = 2;
const int LINE_PARTIALLY_CONNECTED = 3;

class UpcomingStopIconSwitchRoutePainter extends CustomPainter {
  final BACKLINE_WIDTH =
      0.375; // Width of the vertical line behind the stop circle
  Color top_color;
  Color bottom_color;

  UpcomingStopIconSwitchRoutePainter(
    this.top_color,
    this.bottom_color
  );

  @override
  void paint(Canvas canvas, Size size) {

    Paint fill_paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top_color, bottom_color]
      ).createShader(Rect.fromLTWH(0,0,size.width,size.height));

    canvas.drawRect(
      Rect.fromLTWH(
        (1.0 - BACKLINE_WIDTH) / 2 * size.width,
        0,
        size.width * BACKLINE_WIDTH,
        size.height,
      ),
      fill_paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class UpcomingStopIconPainter extends CustomPainter {
  // This is a CustomPainter that generates the subway-style icons to the left
  // of each upcoming stop in the list.
  // top_line_style and bottom_line_style can be one of the above constants:
  //    LINE_CONNECTED, LINE_DISCONNECTED, or LINE_PARTIALLY_CONNECTED

  final BACKLINE_WIDTH =
      0.375; // Width of the vertical line behind the stop circle

  int top_line_style = 1;
  int bottom_line_style = 1;
  bool is_big_dot = false;
  Color routeColor = UPCOMING_STOP_COLOR;
  bool isDarkMode = false;

  UpcomingStopIconPainter(
    this.top_line_style,
    this.bottom_line_style,
    this.is_big_dot,
    this.routeColor,
    this.isDarkMode,
  );

  Paint white_fill_paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  Paint white_stroke_paint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {

    Paint big_stop_stroke_paint = Paint()
    ..color = isDarkMode ? BIG_STOP_BORDER_COLOR_DARKMODE : BIG_STOP_BORDER_COLOR_LIGHTMODE
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

    Paint big_stop_fill_paint = Paint()
    ..color = isDarkMode ? BIG_STOP_FILL_COLOR_DARKMODE : BIG_STOP_FILL_COLOR_LIGHTMODE
    ..style = PaintingStyle.fill;


    Paint fill_paint = Paint()
      ..color = routeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    Paint stroke_paint = Paint()
      ..color = this.routeColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    double dotWidth = is_big_dot ? size.width * (0.5) : size.width * (0.3);
    double partiallyConnectedDashHeight = 0.1;

    if (top_line_style == LINE_CONNECTED) {
      canvas.drawRect(
        Rect.fromLTWH(
          (1.0 - BACKLINE_WIDTH) / 2 * size.width,
          0,
          size.width * BACKLINE_WIDTH,
          size.height / 2,
        ),
        fill_paint,
      );
    } else if (top_line_style == LINE_PARTIALLY_CONNECTED) {
      canvas.drawRect(
        Rect.fromLTWH(
          (1.0 - partiallyConnectedDashHeight) / 2 * size.width,
          0 + partiallyConnectedDashHeight * (15.0),
          size.width * partiallyConnectedDashHeight,
          size.height * partiallyConnectedDashHeight,
        ),
        fill_paint,
      );
    }

    if (bottom_line_style == LINE_CONNECTED) {
      canvas.drawRect(
        Rect.fromLTWH(
          (1.0 - BACKLINE_WIDTH) / 2 * size.width,
          size.height / 2,
          size.width * BACKLINE_WIDTH,
          size.height,
        ),
        fill_paint,
      );
    } else if (bottom_line_style == LINE_PARTIALLY_CONNECTED) {
      canvas.drawRect(
        Rect.fromLTWH(
          (1.0 - partiallyConnectedDashHeight) / 2 * size.width,
          size.height -
              partiallyConnectedDashHeight * size.height * (3.0 / 2.0),
          size.width * partiallyConnectedDashHeight,
          partiallyConnectedDashHeight * size.height,
        ),
        fill_paint,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: dotWidth,
        height: dotWidth,
      ),
      is_big_dot ? big_stop_fill_paint : white_fill_paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: dotWidth,
        height: dotWidth,
      ),
      is_big_dot ? big_stop_stroke_paint : stroke_paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DisplayBusStop {
  String? prediction;
  String name;
  String id;
  String routeCode;

  DisplayBusStop({
    this.prediction,
    required this.name,
    required this.id,
    required this.routeCode
  });
}

class _UpcomingStopsWidgetState extends State<UpcomingStopsWidget> {
  List<DisplayBusStop> nextBusStops = List.empty();
  bool isLoading = true;
  bool isExpanded = false;

  void initState() {
    super.initState();

    isExpanded = widget.isExpanded;

    if (isExpanded) {
      // If expanded by default, load data and display it right away
      loadData();
    }
  }



  @override
  void didUpdateWidget(UpcomingStopsWidget oldWidget) {
    // If the user tries to expand the widget, fetch the upcoming stops and display them
    super.didUpdateWidget(oldWidget);

    if (isLoading && widget.isExpanded) {
      loadData();

      setState(() {
        isExpanded = widget.isExpanded;
      });
    }
  }

  Future<void> loadData() async {
    // Downloads the upcoming stops and updates the state so they appear before your very eyes!

    if (!isLoading) return; // Data already loaded, no need to load again
    if (widget.vehicleId == null || widget.stopsToDisplayOverride != null) {
      setState(() {
        isLoading = false;
        nextBusStops = [];
        if (widget.stopsToDisplayOverride == null) return;
        for (ArrivalTimeLocation loc in widget.stopsToDisplayOverride!) {
          nextBusStops.add(
            DisplayBusStop(
              name: loc.name,
              id: loc.stopId ?? "000",
              routeCode: widget.routeCodeOverride ?? "",
              prediction: loc.arrivalTime
            )
          );
        }
      });
      return; // Use override data intead of loading it from the internet
    }

    var result;

    try {
      debugPrint("Loading data......");
      result = await fetchNextBusStops(widget.vehicleId!);
      debugPrint("    Got result! $result");
    } catch (e) {
      debugPrint("Error getting stops: $e");
      return;
    }

    // bus times aren't sorted for some reason
    result.sort((a, b) {
      // sorting function

      // edge cases
      if (a.prediction == "DUE") {
        return -1;
      }
      if (b.prediction == "DUE") {
        return 1;
      }

      int idA = int.parse(a.prediction);
      int idB = int.parse(b.prediction);
      return idA.compareTo(idB);
    });

    List<BusStopWithPrediction> results_filtered = [];

    if (widget.filterAfterPredictionTime == 0 || widget.filterAfterStop == "") {
      // If filtering parameters aren't present, don't filter the data
      results_filtered = result;
    } else {
      bool filter_check_passed = false;

      for (int i = 0; i < result.length; i++) {
        // Filters the data for a particular stop and prediction time. So, i.e. if you're
        //     displaying this widget in the bus stop predictions list, you can only show
        //     the upcoming stops AFTER the bus gets to CCTC in 15 minutes.
        //     (i.e. set filterAfterStop to "C520" (CCTC) and filterAfterPredictionTime to
        //     12ish (to account for 2-3min differences in prediction times))

        int resultPrediction = (result[i].prediction == "DUE")
            ? 0
            : int.parse(result[i].prediction);

        if (!filter_check_passed &&
            resultPrediction >= widget.filterAfterPredictionTime &&
            result[i].id == widget.filterAfterStop) {
          filter_check_passed = true;
        }

        if (filter_check_passed) {
          debugPrint(
            "    ${result[i].name} found after both conditions met, adding...",
          );
          results_filtered.add(result[i]);
        }
      }
    }

    if (!mounted) return; // If the object is destroyed, don't set its state

    setState(() {
      nextBusStops = results_filtered.map((BusStopWithPrediction origStop) {
        return DisplayBusStop(
            name: origStop.name, id: origStop.id, routeCode: origStop.busRouteCode, prediction: origStop.prediction);
        }).toList();
      isLoading = false;
    });
  }

  GestureDetector getUpcomingStopRow( // TODO: Add a lineTopColor and lineBottomColor attribute to the constructor and pass those in from the loop (so that it works when the bus color changes)
    int lineTopStyle,
    int lineBottomStyle,
    bool isKeyStop,
    // String prediction,
    // String stopName,
    // String stopId,
    DisplayBusStop stop,
    Function(String, String)? onBusStopClick,
    Color topColor,
    Color bottomColor
  ) {
    // Builds a single line of the upcoming stops prediction. A single line includes
    //    * A stop icon (the subway-style icon to the left, with the back line)
    //    * The name of the stop ("Stockwell Hall Outbound")
    //    * The prediction ("10 min")
    //    * A right-arrow chevron icon (If onBusStopClick function is set), to inform
    //        the user that it's clickable

    // lineTopStyle and lineBottomStyle are LINE_CONNECTED, LINE_DISCONNECTED, etc.
    
    String predictionText = "";
    if (widget.stopsToDisplayOverride != null){
      predictionText = stop.prediction != null? stop.prediction! : "";
    } else if (stop.prediction == "DUE") {
      predictionText = "Now";
    } else{
      predictionText = stop.prediction != null? (stop.prediction! + " min") : "";
    }
    

    return GestureDetector(
      onTap: () {
        onBusStopClick?.call(stop.name, stop.id);
      },
      child: Row(
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: UpcomingStopIconPainter(
              lineTopStyle,
              lineBottomStyle,
              isKeyStop,
              // widget.color,
              topColor,
              isDarkMode(context)
            ),
          ),
          Expanded(
            child: Text(
              stop.id + ": " + stop.name,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: isKeyStop ? FontWeight.bold : FontWeight.normal,
                height: 1.15
              ),
            ),
          ),
          (stop.prediction != null) ? Text(predictionText, style: TextStyle(fontSize: 16.0)) : SizedBox.shrink(),

          (onBusStopClick != null)
              ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Row getUpcomingStopRouteChangeDetectedRow( // TODO: Add a lineTopColor and lineBottomColor attribute to the constructor and pass those in from the loop (so that it works when the bus color changes)
    String changingToRouteName,
    String routeIDOfPreviousBus,
    String routeIDOfNextBus
  ) {
    // Builds a special single line of the upcoming stops prediction, used for messages like "Bus changes to Commuter South". A single line includes

    return Row(
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: UpcomingStopIconSwitchRoutePainter(
              RouteColorService.getRouteColor(routeIDOfPreviousBus),
              RouteColorService.getRouteColor(routeIDOfNextBus)
            ),
          ),

          
          Expanded(
            child: Center(
              child: Text(
                "Bus changes to $changingToRouteName",
                style: TextStyle(
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
  }

  // NEXT STEPS TODO: Add key stops to TheRide!

  static const int DETAILED_STOPS_TO_SHOW = 4; // Number of detailed stops to show per bus
      // (Detailed stops are shown at the beginning and are connected with a solid line.)
      // Only applies if showAbridgedStops is set to true.
  
  @override
  Widget build(BuildContext context) {
    

    List<Widget> rowElements = [];

    // List<BusStopWithPrediction> additionalKeyStops = [];
    List<DisplayBusStop> additionalKeyStops = [];
    
    int numDetailedStopsToShow = 0;
    String lastStopRouteCode = "";
    

    
    if (widget.showAbridgedStops) {
      numDetailedStopsToShow = min(DETAILED_STOPS_TO_SHOW, nextBusStops.length);

      // Add the additional key stops to the array if we're abridging the detailed stops
      for (int i = DETAILED_STOPS_TO_SHOW; i < nextBusStops.length; i++) {
      if (KEY_STOPS.containsKey(nextBusStops[i].id)) {
        nextBusStops[i].name = KEY_STOPS[nextBusStops[i].id]!;
        additionalKeyStops.add(nextBusStops[i]);
      }
    }
    } else {
      numDetailedStopsToShow = nextBusStops.length;
    }

    // Sets up the array of detailed stops (shown at the top, connected with a solid line)
    for (int i = 0; i < numDetailedStopsToShow; i++) {
      // BusStopWithPrediction upcomingStop = nextBusStops[i];
      DisplayBusStop upcomingStop = nextBusStops[i];

      bool isKeyStop = false;
      //String stopName = upcomingStop.name;
      if (KEY_STOPS.containsKey(upcomingStop.id)) {
        isKeyStop = true;
        upcomingStop.name = KEY_STOPS[upcomingStop.id]!;
        //stopName = KEY_STOPS[upcomingStop.id] ?? upcomingStop.name;
      }

      // Check if we need to add the "Bus changes route to ..." message
      if (lastStopRouteCode != "" && lastStopRouteCode != upcomingStop.routeCode) {
        rowElements.add(
          getUpcomingStopRouteChangeDetectedRow(
            getPrettyRouteName(upcomingStop.routeCode),
            lastStopRouteCode,
            upcomingStop.routeCode)
        );
      }

      rowElements.add(
        getUpcomingStopRow(
          (i == 0) ? LINE_DISCONNECTED : LINE_CONNECTED,
          (i == numDetailedStopsToShow - 1)
              ? (additionalKeyStops.isNotEmpty
                    ? LINE_PARTIALLY_CONNECTED
                    : LINE_DISCONNECTED)
              : LINE_CONNECTED,
          isKeyStop,
          upcomingStop,
          widget.onBusStopClick,
          RouteColorService.getRouteColor(upcomingStop.routeCode),
          RouteColorService.getRouteColor(upcomingStop.routeCode),
        ),
      );

      lastStopRouteCode = upcomingStop.routeCode;
    }

    // Sets up array of additional key stops (shown below the detailed stops and connected
    // with a dashed line)
    if (widget.showAbridgedStops) {
      // These key stops are only shown if the detailed stops were abridged
      for (int i = 0; i < additionalKeyStops.length; i++) {
        DisplayBusStop upcomingStop = additionalKeyStops[i];
        //String stopName = KEY_STOPS[upcomingStop.id] ?? upcomingStop.name;
        bool isKeyStop = true; // All these stops are key stops

        rowElements.add(
          getUpcomingStopRow(
            LINE_PARTIALLY_CONNECTED,
            (i == additionalKeyStops.length - 1)
                ? LINE_DISCONNECTED
                : LINE_PARTIALLY_CONNECTED,
            isKeyStop,
            upcomingStop,
            widget.onBusStopClick,
            RouteColorService.getRouteColor(upcomingStop.routeCode),
            RouteColorService.getRouteColor(upcomingStop.routeCode),
          ),
        );

        lastStopRouteCode = upcomingStop.routeCode;
      }
    }

    if (widget.shouldAnimate) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          height: widget.isExpanded ? null : 0,
          child: (rowElements.length > 0)
              ? Column(
                  children: [
                    ...rowElements,
                    (widget.showSeeMoreButton && !isLoading)
                        ? (TextButton(
                            child: const Text("See all stops for this bus"),
                            onPressed: () {
                              widget.showBusSheet?.call(widget.vehicleId!);
                            },
                          ))
                        : const SizedBox.shrink(),
                  ],
                )
              : isLoading
              ? (isExpanded)? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: widget.color,)),
              ) : SizedBox.shrink()
              : widget.childIfNoUpcomingStopsFound,
        ),
      );
    } else {
      return (rowElements.length > 0)
          ? Column(children: rowElements)
          : isLoading
          ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: widget.color,)),
          )
          : widget.childIfNoUpcomingStopsFound;
    }
  }
}

class UpcomingStopsWidget extends StatefulWidget {
  final Color color;
  final String routeId;
  final String? vehicleId;
  final bool isExpanded;
  final bool shouldAnimate;
  final bool showAbridgedStops;
  final int filterAfterPredictionTime;
  final String filterAfterStop;
  final bool showSeeMoreButton;
  final Function(String)? showBusSheet;
  final Function(String, String)? onBusStopClick;
  final Widget childIfNoUpcomingStopsFound;
  final List<ArrivalTimeLocation>? stopsToDisplayOverride;
  final String? routeCodeOverride;

  @override
  State<StatefulWidget> createState() => _UpcomingStopsWidgetState();

  UpcomingStopsWidget({
    required this.color,
    required this.routeId,
    String? this.vehicleId,
    // TODO: Allow passing in of stops instead of a vehicle ID
    List<ArrivalTimeLocation>? this.stopsToDisplayOverride,
    String? this.routeCodeOverride,

    required bool this.isExpanded,
    this.shouldAnimate = true,
    this.showAbridgedStops = true,
    this.filterAfterPredictionTime = 0,
    this.filterAfterStop = "",
    this.showSeeMoreButton = false,
    this.showBusSheet,
    this.onBusStopClick,
    required this.childIfNoUpcomingStopsFound,
  });
}

Widget rideIcon(Color color, String id){
  return Container( // Bus circular icon
    width: 50,
    height: 35,
    decoration: BoxDecoration(
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(39), // should be 27.5 (55 divided by 2) but 39 works too
      color: color,
    ),
    alignment: Alignment.center,
    child: Text(
      id,
      style: TextStyle(
        color: RouteColorService.getContrastingColor(
          id,
        ),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

Widget michiganBusIcon(Color color, String id){
  return Container( // Bus circular icon
    width: 35,
    height: 35,
    decoration: BoxDecoration(
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(39), // should be 27.5 (55 divided by 2) but 39 works too
      color: color,
    ),
    alignment: Alignment.center,
    child: Text(
      id,
      style: TextStyle(
        color: RouteColorService.getContrastingColor(
          id,
        ),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      textAlign: TextAlign.center,
    ),
  );
}