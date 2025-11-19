import 'dart:math';

import 'package:bluebus/services/bus_info_service.dart';
import 'package:flutter/material.dart';
import '../models/bus_stop.dart';

final Map<String, String> KEY_STOPS = {
  // Key stops are shown larger in the list of upcoming stops for each bus.
  //     You can also rename them here!
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
  "S002":
      "Crisler Center/Michigan Stadium", // Crisler Center Lot SC-5 (Southbound)
  "C206": "Oxford Housing", // Self-explanatory
  "M323": "Wall Street Parking Structure",
  "N422": "Northwood Fire Station", // "Top" of Northwood route
  "N437": "Northwood V",
};

const Color UPCOMING_STOP_COLOR = Color.fromARGB(255, 85, 119, 130);
const Color BIG_STOP_BORDER_COLOR = Color.fromARGB(255, 91, 96, 100);

const int LINE_CONNECTED = 1;
const int LINE_DISCONNECTED = 2;
const int LINE_PARTIALLY_CONNECTED = 3;

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

  UpcomingStopIconPainter(
    this.top_line_style,
    this.bottom_line_style,
    this.is_big_dot,
    this.routeColor,
  );

  Paint white_fill_paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  Paint white_stroke_paint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  Paint big_stop_stroke_paint = Paint()
    ..color = BIG_STOP_BORDER_COLOR
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
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
      white_fill_paint,
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

class _UpcomingStopsWidgetState extends State<UpcomingStopsWidget> {
  var nextBusStops = List.empty();
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

    var result;

    try {
      debugPrint("Loading data......");
      result = await fetchNextBusStops(widget.vehicleId);
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

    var results_filtered = [];

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
      nextBusStops = results_filtered;
      isLoading = false;
    });
  }

  GestureDetector getUpcomingStopRow(
    int lineTopStyle,
    int lineBottomStyle,
    bool isKeyStop,
    String prediction,
    String stopName,
    String stopId,
    Function(String, String)? onBusStopClick,
  ) {
    // Builds a single line of the upcoming stops prediction. A single line includes
    //    * A stop icon (the subway-style icon to the left, with the back line)
    //    * The name of the stop ("Stockwell Hall Outbound")
    //    * The prediction ("10 min")
    //    * A right-arrow chevron icon (If onBusStopClick function is set), to inform
    //        the user that it's clickable

    // lineTopStyle and lineBottomStyle are LINE_CONNECTED, LINE_DISCONNECTED, etc.
    String predictionText = "${prediction} min";
    if (prediction == "DUE") predictionText = "Now";

    return GestureDetector(
      onTap: () {
        onBusStopClick?.call(stopName, stopId);
      },
      child: Row(
        children: [
          CustomPaint(
            size: Size(40, 40),
            painter: UpcomingStopIconPainter(
              lineTopStyle,
              lineBottomStyle,
              isKeyStop,
              widget.color,
            ),
          ),
          Expanded(
            child: Text(
              stopName,
              style: TextStyle(
                fontSize: isKeyStop ? 20.0 : 14.0,
                fontWeight: isKeyStop ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(predictionText, style: TextStyle(fontSize: 16.0)),

          (onBusStopClick != null)
              ? Icon(Icons.chevron_right, color: Colors.grey, size: 20)
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  static const int DETAILED_STOPS_TO_SHOW = 4; // Number of detailed stops to show per bus
      // (Detailed stops are shown at the beginning and are connected with a solid line.)
      // Only applies if showAbridgedStops is set to true.
  
  @override
  Widget build(BuildContext context) {
    

    List<Widget> rowElements = [];

    List<BusStopWithPrediction> additionalKeyStops = [];
    
    int numDetailedStopsToShow = 0;
    if (widget.showAbridgedStops) {
      numDetailedStopsToShow = min(DETAILED_STOPS_TO_SHOW, nextBusStops.length);

      // Add the additional key stops to the array if we're abridging the detailed stops
      for (int i = DETAILED_STOPS_TO_SHOW; i < nextBusStops.length; i++) {
      if (KEY_STOPS.containsKey(nextBusStops[i].id)) {
        additionalKeyStops.add(nextBusStops[i]);
      }
    }
    } else {
      numDetailedStopsToShow = nextBusStops.length;
    }

    // Sets up the array of detailed stops (shown at the top, connected with a solid line)
    for (int i = 0; i < numDetailedStopsToShow; i++) {
      BusStopWithPrediction upcomingStop = nextBusStops[i];

      bool isKeyStop = false;
      String stopName = upcomingStop.name;
      if (KEY_STOPS.containsKey(upcomingStop.id)) {
        isKeyStop = true;
        stopName = KEY_STOPS[upcomingStop.id] ?? upcomingStop.name;
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
          upcomingStop.prediction,
          stopName,
          upcomingStop.id,
          widget.onBusStopClick,
        ),
      );
    }

    // Sets up array of additional key stops (shown below the detailed stops and connected
    // with a dashed line)
    if (widget.showAbridgedStops) {
      // These key stops are only shown if the detailed stops were abridged
      for (int i = 0; i < additionalKeyStops.length; i++) {
        BusStopWithPrediction upcomingStop = additionalKeyStops[i];
        String stopName = KEY_STOPS[upcomingStop.id] ?? upcomingStop.name;
        bool isKeyStop = true; // All these stops are key stops

        rowElements.add(
          getUpcomingStopRow(
            LINE_PARTIALLY_CONNECTED,
            (i == additionalKeyStops.length - 1)
                ? LINE_DISCONNECTED
                : LINE_PARTIALLY_CONNECTED,
            isKeyStop,
            upcomingStop.prediction,
            stopName,
            upcomingStop.id,
            widget.onBusStopClick,
          ),
        );
      }
    }

    if (widget.shouldAnimate) {
      return AnimatedSize(
        duration: Duration(milliseconds: 300),
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
                            child: Text("See all stops for this bus"),
                            onPressed: () {
                              widget.showBusSheet?.call(widget.vehicleId);
                            },
                          ))
                        : SizedBox.shrink(),
                  ],
                )
              : isLoading
              ? SizedBox.shrink()
              : widget.childIfNoUpcomingStopsFound,
        ),
      );
    } else {
      return (rowElements.length > 0)
          ? Column(children: rowElements)
          : isLoading
          ? SizedBox.shrink()
          : widget.childIfNoUpcomingStopsFound;
    }
  }
}

class UpcomingStopsWidget extends StatefulWidget {
  final Color color;
  final String routeId;
  final String vehicleId;
  final bool isExpanded;
  bool shouldAnimate = true;
  bool showAbridgedStops = true;
  int filterAfterPredictionTime = 0;
  String filterAfterStop = "";
  bool showSeeMoreButton = false;
  Function(String)? showBusSheet;
  Function(String, String)? onBusStopClick;
  Widget childIfNoUpcomingStopsFound;

  @override
  State<StatefulWidget> createState() => _UpcomingStopsWidgetState();

  UpcomingStopsWidget({
    required this.color,
    required this.routeId,
    required String this.vehicleId,
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
