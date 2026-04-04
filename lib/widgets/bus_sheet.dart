import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/bus_repository.dart';
import 'package:bluebus/services/sheet_navigation_manager.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bus.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart';
import 'upcoming_stops_widget.dart';

bool isNumber(String? s) {
  if (s != null && int.tryParse(s) != null) {
    // busID is numeric, so it's a ride bus
    return true;
  } 
  return false;
}

class BusSheet extends StatefulWidget implements NavigableSheet {
  final String busID;
  final ScrollController scrollController;
  final void Function(String name, String id) onSelectStop;
  final GlobalKey<_BusSheetState> stateKey;

  BusSheet._({
    // Key? key,
    // Key? stateKey,
    required this.stateKey,
    required this.busID,
    required this.onSelectStop,
    required this.scrollController,
  }) : super(key: stateKey);

  factory BusSheet({
    required String busID,
    required void Function(String, String) onSelectStop,
    required ScrollController scrollController,
  }) {
    final key = GlobalKey<_BusSheetState>();
    return BusSheet._(stateKey: key, busID: busID, onSelectStop: onSelectStop, scrollController: scrollController);
  }

  @override
  State<BusSheet> createState() {
    return _BusSheetState();
  }
  
  @override
  void setShouldUseScrollController(bool shouldUseScrollController) {
    // debugPrint("BusSheet: Got setCustomScrollController call with ${newScrollController}");
    stateKey.currentState?.setShouldUseScrollController(shouldUseScrollController);
  }
}

class _BusSheetState extends State<BusSheet> {
  late Bus? currBus = BusRepository.getBus(widget.busID);
  late Future<List<BusStopWithPrediction>> futureBusStops;
  bool shouldUseScrollControler = true;

  // The shouldUseScrollControler parameter necessary so that when two widgets occupy the same Sheet
  // (i.e. when one sheet is displayed on top of another via SheetNavigator), both Sheets don't
  // fight over the scroll controller and make scrolling janky. The SheetNavigator feeds a "dummy"
  // scroll controller when this sheet is displayed behind something else
  void setShouldUseScrollController(bool shouldUseScrollControlerIn) {
    debugPrint("BusSheet: INSIDE: setShouldUseScrollController() call: $shouldUseScrollControlerIn");
    setState(() {
      shouldUseScrollControler = shouldUseScrollControlerIn;
    });
  }
  ScrollController? getScrollController() {
    if (!shouldUseScrollControler) {
      debugPrint("getScrollController() call, returning null");
      return null;
    }
    debugPrint("getScrollController call(), returning the vanilla one");
    return widget.scrollController;
  }
  
  @override
  void initState() {
    super.initState();
    futureBusStops = fetchNextBusStops(widget.busID);
  }

  @override
  Widget build(BuildContext context) {
    // There was a really weird bug where _BusSheetState would get a busID that doesn't exist so currBus would be null.
    // This accounts for that.
    if (currBus == null) return Text("Bus not found");

    // return Text("HI");

    debugPrint("BusSheet: Building...");

    final bus = currBus!;

    Widget output = Container(
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          SheetBoxShadow
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 10,
          top: 0,
          right: 20,
          bottom: 0,
        ),
        child: SingleChildScrollView(
          // controller: widget.scrollController,
          // controller: getScrollController(),
          controller: null,

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // spacer
              const SizedBox(height: 20),

              // header (if the bus id is a number it's a ride bus)
              isNumber(bus.routeId) ? theRideHeader(bus, context) : michiganBusHeader(bus, context),

              SizedBox(height: 20),

              UpcomingStopsWidget(
                color: RouteColorService.getRouteColor(bus.routeId),
                routeId: bus.routeId,
                vehicleId: bus.id,
                isExpanded: true,
                shouldAnimate: false,
                showAbridgedStops: false,
                onBusStopClick: (String stopName, String stopId) {
                  widget.onSelectStop(stopName, stopId);
                },
                childIfNoUpcomingStopsFound: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: Center(
                    child: const Text(
                        "No upcoming stops found",
                        style: TextStyle(
                          fontSize: 16.0,
                          fontStyle: FontStyle.italic
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ),
                )
              ),

              SizedBox(height: 10), // Extra padding on the bottom to look nicer
            ],
          ),
        ),
      ),
    );
    debugPrint("BusSheet: Finished building");
    return output;
  }
}

Widget michiganBusHeader(Bus bus, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(
      left: 10,
      right: 0,
      top: 0,
      bottom: 0,
    ),
    child: Row(
      children: [
        Container( // Bus circular icon
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bus.routeColor,
          ),
          alignment: Alignment.center,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: Text(
              bus.routeId,
              style: TextStyle(
                color: RouteColorService.getContrastingColor(
                  bus.routeId,
                ),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        SizedBox(width: 15),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                getPrettyRouteName(bus.routeId),
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                  height: 1
                ),
              ),

              SizedBox(height: 6,),

              Text(
                "Bus ${bus.id}",
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  height: 1
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget theRideHeader(Bus bus, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(
      left: 10,
      right: 0,
      top: 0,
      bottom: 0,
    ),
    child: Row(
      children: [
        Container( // Bus circular icon
          width: 78,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(39), // should be 27.5 (55 divided by 2) but 39 works too
            color: bus.routeColor,
          ),
          alignment: Alignment.center,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: Text(
              bus.routeId,
              style: TextStyle(
                color: RouteColorService.getContrastingColor(
                  bus.routeId,
                ),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        SizedBox(width: 15),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getPrettyRouteName(bus.routeId),
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                  height: 1
                ),
              ),

              SizedBox(height: 5,),

              Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      "assets/rideIcon.png",
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
          
                  SizedBox(width: 8),
          
                  Text(
                    "Bus ${bus.id}",
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

