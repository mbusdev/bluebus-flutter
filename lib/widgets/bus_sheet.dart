import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/bus_repository.dart';
import 'package:bluebus/services/sheet_navigation_manager.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/widgets/dialog.dart';
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

class BusSheet extends StatefulWidget {
  final String busID;
  ScrollController? scrollController;
  final void Function(String name, String id) onSelectStop;

  BusSheet({
    required this.busID,
    required this.onSelectStop,
    this.scrollController, // Note: scrollController should be null ONLY if it's inside a SheetNavigator (in which case the SheetNavigator provides it through SheetNavigationContext).
  });

  @override
  State<BusSheet> createState() {
    return _BusSheetState();
  }
  
}

class _BusSheetState extends State<BusSheet> {
  late Bus? currBus = BusRepository.getBus(widget.busID);
  late Future<List<BusStopWithPrediction>> futureBusStops;  


  @override
  void initState() {
    super.initState();
    if (currBus == null) { 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        Navigator.of(context).pop();

        showMaizebusOKDialog(
          contextIn: context,
          title: "Uh Oh!",
          content: "Unable to fetch bus data. Please check your internet connection and try again.",
        );
      }); 
    } else { 
      futureBusStops = fetchNextBusStops(widget.busID);
    }
  }

  @override
  Widget build(BuildContext context) {
    // There was a really weird bug where _BusSheetState would get a busID that doesn't exist so currBus would be null.
    // This accounts for that.
    // Update: Fixed the blank text "bus not found", should 

    if (currBus == null) return Text("Bus Not Found");

    final bus = currBus!;

    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [SheetBoxLeftShadow]
        
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 10,
          top: 0,
          right: 20,
          bottom: 0,
        ),
        child: SingleChildScrollView(
          controller: widget.scrollController ?? SheetNavigationContext.of(context)?.scrollController,

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
        RouteIcon.large(bus.routeId),

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
        RouteIcon.large(bus.routeId),

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

