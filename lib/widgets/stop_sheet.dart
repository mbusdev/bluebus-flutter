import 'package:bluebus/providers/bus_provider.dart';
import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../constants.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart';
import 'package:intl/intl.dart';
import 'upcoming_stops_widget.dart';

bool isRide(String? s) {
  if (s != null && int.tryParse(s) != null) {
    // busID is numeric, so it's a ride bus
    return true;
  } 
  return false;
}

class StopSheet extends StatefulWidget {
  final String stopID;
  final String stopName;
  final Future<void> Function(String, String) onFavorite;
  final Future<void> Function(String, String) onUnFavorite;
  final void Function() onGetDirections;
  final void Function(String) showBusSheet;
  final BusProvider busProvider;

  StopSheet({
    Key? key,
    required this.stopID,
    required this.stopName,
    required this.onFavorite,
    required this.onUnFavorite,
    required this.onGetDirections,
    required this.showBusSheet,
    required this.busProvider,
  }) : super(key: key);

  @override
  State<StopSheet> createState() => _StopSheetState();
}

String futureTime(String minutesInFuture) {
  int min = int.parse(minutesInFuture);
  DateTime now = DateTime.now();
  DateTime futureTime = now.add(Duration(minutes: min));
  return DateFormat('h:mm a').format(futureTime);
}

String format(String text) {
  if (text.isEmpty) {
    return '';
  }

  // Capitalize the first character and lowercase the rest
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

class _ExpandableStopWidgetState extends State<ExpandableStopWidget> {
  bool is_expanded = false;

  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    // throw UnimplementedError();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            // behavior: HitTestBehavior.opaque, // Clicking anywhere on the bus opens the upcoming stops list
            onTap: () {
              setState(() {
                is_expanded = !is_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: Row(
                children: [
                  Container( // Circular icon on the left (with the bus code, e.g. "NW")
                    width: isRide(widget.busId) ? 45 : 40,
                    height: isRide(widget.busId) ? 35 : 40, 
                    decoration: isRide(widget.busId) ? 
                      // ride icon
                      BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(20),
                        color: RouteColorService.getRouteColor(widget.busId),
                      ) :
                      // michigan icon
                      BoxDecoration(
                        shape: BoxShape.circle,
                        color: RouteColorService.getRouteColor(widget.busId),
                      ),
                      alignment: Alignment.center,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                        child: Text(
                          widget.busId,
                          style: TextStyle(
                            color: RouteColorService.getContrastingColor(widget.busId), 
                            fontSize: 20,
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
                          getPrettyRouteName(widget.busId),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),

                        Row(
                          children: [
                            Text(
                              (widget.busPrediction != "DUE")
                                  ? "${futureTime(widget.busPrediction)}"
                                  : "within the next minute",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Urbanist',
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),

                            Text(
                              (widget.busProvider.containsBus(widget.vehicleId))
                                  ? " • Live"
                                  : " • Estimated",
                              style: TextStyle(
                                fontSize: 16.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  (widget.busPrediction != "DUE")
                      ? Column(
                          children: [
                            Text(
                              widget.busPrediction,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 20,
                                height: 0,
                              ),
                            ),
                            Text(
                              "min",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 0,
                              ),
                            ),
                          ],
                        )
                      : SizedBox.shrink(),
                  
                  SizedBox(width: 5,),

                  is_expanded
                      ? Icon(Icons.expand_less)
                      : Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: UpcomingStopsWidget(
            color: RouteColorService.getRouteColor(widget.busId),
            routeId: widget.routeId,
            vehicleId: widget.vehicleId,
            isExpanded: is_expanded,
            shouldAnimate: true,
            filterAfterPredictionTime: (widget.busPrediction == "DUE")
                ? 0
                : int.parse(widget.busPrediction) -
                      5, // Minus five minutes to account for prediction time discrepancies
            filterAfterStop: widget.stopId,
            showSeeMoreButton: true,
            showBusSheet: widget.showBusSheet,
            childIfNoUpcomingStopsFound: Padding(
              padding: EdgeInsets.only(left: 55),
              child: Text(
                "No upcoming stops found for this bus",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
      ],
    );
    // );
  }
}

class ExpandableStopWidget extends StatefulWidget {
  final String routeId;
  final String vehicleId;
  final String busId;
  final String busPrediction;
  final String busDirection;
  final String stopId;
  final Function(String) showBusSheet;
  final BusProvider busProvider;

  @override
  State<StatefulWidget> createState() => _ExpandableStopWidgetState();

  const ExpandableStopWidget({
    required this.routeId,
    required this.vehicleId,
    required this.busId,
    required this.busPrediction,
    required this.busDirection,
    required this.stopId,
    required this.showBusSheet,
    required this.busProvider,
  });
}

class _StopSheetState extends State<StopSheet> {
  late Future<(List<BusWithPrediction>, bool)> loadedStopData;
  bool? _isFavorited;

  // for select bus stops with images
  late bool imageBusStop;
  late String imagePath;

  @override
  void initState() {
    super.initState();
    loadedStopData = fetchStopData(widget.stopID);
    imageBusStop =
        (widget.stopID == "C250") ||
        (widget.stopID == "N406") ||
        (widget.stopID == "N405") ||
        (widget.stopID == "N550") ||
        (widget.stopID == "N551") ||
        (widget.stopID == "N553") ||
        (widget.stopID == "C251");
    if (widget.stopID == "C250") {
      imagePath = "assets/CCTC.jpg";
    }
    if (widget.stopID == "C251") {
      imagePath = "assets/CCTC_Ruthven.jpg";
    }
    if (widget.stopID == "N406") {
      imagePath = "assets/FXB_outbound.jpg";
    }
    if (widget.stopID == "N405") {
      imagePath = "assets/FXB_inbound.jpg";
    }
    if (widget.stopID == "N550") {
      imagePath = "assets/Pierpont.jpg";
    }
    if (widget.stopID == "N551") {
      imagePath = "assets/PierpontBursley.jpg";
    }
    if (widget.stopID == "N553") {
      imagePath = "assets/PierpontNorthwood.jpg";
    }
  }

  void _refreshData() {
    setState(() {
      loadedStopData = fetchStopData(widget.stopID);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // stacking the sheet on top of a gesture detector so you can close it by tapping out of it
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(),
          ),
        ),
        FutureBuilder(
          future: loadedStopData,
          builder: (context, snapshot) {
            List<BusWithPrediction> arrivingBuses = [];

            if (snapshot.hasData) {
              arrivingBuses = snapshot.data!.$1;
              arrivingBuses.sort(
                (lhs, rhs) => (int.tryParse(lhs.prediction) ?? 0).compareTo(int.tryParse(rhs.prediction) ?? 0)
              );
              if (_isFavorited == null) {
                _isFavorited = snapshot.data!.$2;
              }
            }

            double initialSize = 0.9;

            if (snapshot.hasData) {
              final itemCount = arrivingBuses.length;

              // edge case
              if (itemCount == 0) {
                initialSize = 0.5;
              }
            } else {
              // A fixed initial size for loading or error states.
              initialSize = 0.4;
              if (imageBusStop) {
                initialSize = 0.6;
              }
            }

            // we know image dimensions, so we can use the width to find the height
            // with a lil simple math
            double heightOfImage = (imageBusStop)? ((MediaQuery.sizeOf(context).width) * 0.54345703125) : 0;

            double paddingBelowButtons = (MediaQuery.of(context).padding.bottom == 0.0)? 20 : MediaQuery.of(context).padding.bottom;

            return DraggableScrollableSheet(
              initialChildSize: initialSize,
              minChildSize: 0.0, // leave at 0.0 to allow full dismissal
              maxChildSize: initialSize,
              snap: true,
              snapSizes: [initialSize],
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: getColor(context, ColorType.background),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      SheetBoxShadow
                    ]
                  ),

                  // overflow box lets the stuff inside not shrink when page is being closed
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: MediaQuery.of(context).size.height * initialSize, 
                    // In this stack, 
                    // First (bottom) layer is image, which sometimes doesn't exist
                    // Second layer is another stack. Inside that stack is: 
                    //    first layer: the the main body and content
                    //    second layer is a box with a gradient
                    //    third layer is the buttons themselves
                    child: Stack(
                      children: [
                        (imageBusStop)?
                          // Image of bus stop if it exists
                          ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            child: Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                              ),
                          )
                          // bus stop image does not exist, use empty widget
                        : SizedBox.shrink(),
                    
                        Stack(
                          children: [
                            // yes this column only has one thing. yes this is 
                            // the only way it works becuase the stack won't play
                            // nice without it. Thank you flutter
                            Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    controller: scrollController,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // spacer for image with gradient
                                        Container(
                                          height: heightOfImage,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                getColor(context, ColorType.backgroundGradientStart),  
                                                getColor(context, ColorType.background),                       
                                              ],
                                              stops: [0.7, 1]
                                            ),
                                          ),
                                        ),
                                        
                                        // wrapped in container to add background color
                                        Container(
                                          color: getColor(context, ColorType.background),
                                          child: Column(
                                            children: [
                                              // header
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: (imageBusStop) ? 0 : 20,
                                                  left: 20,
                                                  right: 20,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        widget.stopName,
                                                        style: TextStyle(
                                                          fontFamily: 'Urbanist',
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 30,
                                                          height: 1.1,
                                                        ),
                                                      ),
                                                    ),
                                                                    
                                                    SizedBox(width: 15),
                                                                    
                                                    Column(
                                                      children: <Widget>[
                                                        IntrinsicWidth(
                                                          child: Container(
                                                            height: 25,
                                                            decoration: BoxDecoration(
                                                              color: Colors.amber,
                                                              borderRadius:
                                                                  BorderRadius.circular(7),
                                                            ),
                                                            child: Center(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal: 5,
                                                                    ),
                                                                child: MediaQuery(
                                                                  data: MediaQuery.of(context)
                                                                      .copyWith(
                                                                        textScaler:
                                                                            TextScaler.linear(
                                                                              1.0,
                                                                            ),
                                                                      ),
                                                                  child: Text(
                                                                    widget.stopID,
                                                                    style: TextStyle(
                                                                      color: Colors.black,
                                                                      fontFamily: 'Urbanist',
                                                                      fontWeight:
                                                                          FontWeight.w700,
                                                                      fontSize: 17,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                                                    
                                              SizedBox(height: 20),
                                                                    
                                              // loading text and button
                                              Material(
                                                color: Colors.transparent,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(width: 2),
                                                      Text(
                                                        "Next bus departures",
                                                        style: TextStyle(
                                                          fontFamily: 'Urbanist',
                                                          fontWeight: FontWeight.w400,
                                                          fontSize: 20,
                                                        ),
                                                      ),
                                                      SizedBox(width: 5),
                                                      InkWell(
                                                        customBorder: CircleBorder(),
                                                        onTap: () {
                                                          _refreshData();
                                                        },
                                                        child: SizedBox(
                                                          width: 30,
                                                          height: 30,
                                                          child:
                                                              (snapshot.connectionState ==
                                                                  ConnectionState.waiting)
                                                              ? Align( // For some bizarre reason this is required to get the CircularProgressIndicator to conform to the size of the ConstrainedBox
                                                                  alignment: Alignment.center,
                                                                  child: ConstrainedBox(
                                                                    constraints:
                                                                        BoxConstraints.tightFor(
                                                                          width: 15,
                                                                          height: 15,
                                                                        ),
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                          color: getColor(
                                                                            context,
                                                                            ColorType.opposite,
                                                                          ),
                                                                          strokeWidth: 2.5,
                                                                        ),
                                                                  ),
                                                                )
                                                              : Icon(Icons.refresh),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                                                    
                                                                    
                                              // main page
                                              Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 0,
                                                ),
                                                child:
                                                    (snapshot.connectionState ==
                                                      ConnectionState.waiting)
                                                  ? Center(child: const SizedBox())
                                                  : (snapshot.hasData)
                                                  ? Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        (arrivingBuses.length == 0)
                                                            ?
                                                              FittedBox(
                                                                fit: BoxFit.fill,
                                                                alignment: Alignment.center,
                                                                child: Text(
                                                                  "There are currently no departing buses",
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(
                                                                    fontFamily: 'Urbanist',
                                                                    fontWeight: FontWeight.w400,
                                                                    fontSize: 20,
                                                                  ),
                                                                )
                                                              )
                                                              
                                                            :
                                                              SizedBox(height: 10),
                                                                    
                                                        Column(
                                                          mainAxisSize: MainAxisSize.max,
                                                          children: [
                                                            ListView.separated(
                                                              controller: scrollController,
                                                              shrinkWrap: true,
                                                              physics:
                                                                  NeverScrollableScrollPhysics(),
                                                              itemCount: arrivingBuses.length,
                                                              itemBuilder: (context, index) {
                                                                BusWithPrediction bus =
                                                                    arrivingBuses[index];
                                                                    
                                                                return AnimationConfiguration.staggeredList(
                                                                  position: index,
                                                                  duration: const Duration(milliseconds: 575),
                                                                  delay: const Duration(milliseconds: 100),
                                                                  child: FadeInAnimation(
                                                                    child: ExpandableStopWidget(
                                                                      routeId: bus.id,
                                                                      vehicleId: bus.vehicleId,
                                                                      busId: bus.id,
                                                                      busPrediction:
                                                                          bus.prediction,
                                                                      busDirection: bus.direction,
                                                                      stopId: widget.stopID,
                                                                      showBusSheet:
                                                                          widget.showBusSheet,
                                                                      busProvider:
                                                                          widget.busProvider,
                                                                    )
                                                                  ) 
                                                                  
                                                                  
                                                                );
                                                                
                                                                
                                                              },
                                                              separatorBuilder: (context, index) {
                                                                return Divider(
                                                                  height: 0,
                                                                  indent: 20,
                                                                  endIndent: 20,
                                                                  thickness: 1,
                                                                );
                                                              },
                                                            ),
                    
                                                            SizedBox(height: paddingBelowButtons + 20,)
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                  : Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                      ),
                                                      child: Text(
                                                        "There doesn't seem to be any departure data for this stop",
                                                        style: TextStyle(
                                                          fontFamily: 'Urbanist',
                                                          fontWeight: FontWeight.w400,
                                                          fontSize: 20,
                                                        ),
                                                      ),
                                                    ),
                                                ),
                                            ],
                                          ),
                                        )
                                      ],
                                    )
                                  ),
                                ),
                              ],
                            ),
                    
                            // white box with gradient that the buttons sit on
                            Column(
                              children: [
                                Spacer(), // another spacer to stick this to the bottom
                    
                                Container(
                                  height: paddingBelowButtons + 65,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        getColor(context, ColorType.backgroundGradientStart),  
                                        getColor(context, ColorType.background),                       
                                      ],
                                      stops: [0, 0.2]
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    
                    
                            // bottom buttons
                            Column(
                              children: [
                                Spacer(), // sticks buttons to bottom
                    
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); 
                                          widget.onGetDirections();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: getColor(context, ColorType.mapButtonPrimary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          //elevation: 4
                                        ),
                                        icon: Icon(
                                          Icons.directions, 
                                          color: getColor(context, ColorType.mapButtonIcon),
                                          size: 20,
                                        ), 
                                        label: Text(
                                          'Get Directions',
                                          style: TextStyle(
                                            color: getColor(context, ColorType.primary),
                                            fontSize: 16, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ), 
                                      ),
                                      
                                      Spacer(),
                                            
                                      ElevatedButton(
                                        onPressed: () {
                                          // Read the current state
                                          final bool currentStatus = _isFavorited ?? false;
                                            
                                          // Call the appropriate function
                                          if (currentStatus){
                                            widget.onUnFavorite(widget.stopID, widget.stopName);
                                          } else {
                                            widget.onFavorite(widget.stopID, widget.stopName);
                                          }
                                            
                                          // Update the UI immediately
                                          setState(() {
                                            _isFavorited = !currentStatus;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: getColor(context, ColorType.dim),
                                          shape: CircleBorder(),
                                          shadowColor: Colors.black,
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size(0,0), // Also remove minimum size constraints
                                              fixedSize: Size(40,40),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Remove tap target padding
                                        ),
                                        child: Icon(
                                          (_isFavorited ?? false)?  Icons.favorite : Icons.favorite_border, 
                                          color: (_isFavorited ?? false)? Colors.red : getColor(context, ColorType.opposite),
                                          size: 20,
                                        ), 
                                      ),
                    
                                      SizedBox(width: 10,),
                                            
                                      ElevatedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return Dialog(
                                                constraints: BoxConstraints(
                                                  minWidth: 0.0,
                                                  minHeight: 0.0,
                                                  maxHeight: MediaQuery.of(context).size.height * 0.4
                                                ),
                                                child: Center(
                                                  child: ReminderForm(
                                                    stpid: widget.stopID,
                                                    activeRoutes: arrivingBuses
                                                      .fold([], (xs, x) => xs.contains(x.id) ? xs : xs + [x.id]),
                                                  ),
                                                )
                                              );
                                            }
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: getColor(context, ColorType.dim),
                                          shape: CircleBorder(),
                                          shadowColor: Colors.black,
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size(0,0), // Also remove minimum size constraints
                                              fixedSize: Size(40,40),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Remove tap target padding
                                        ),
                                        child: Icon(
                                          Icons.notifications_none,
                                          color: getColor(context, ColorType.opposite),
                                          size: 20.0,
                                        )
                                      ),
                                    ],
                                  ),
                                ),
                    
                                SizedBox(height: paddingBelowButtons,)
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class ReminderForm extends StatefulWidget {
  const ReminderForm({
    super.key,
    required this.stpid,
    required this.activeRoutes,
  });

  final String stpid;
  // routes that show up in the stop sheet, in order of recency
  final List<String> activeRoutes;
  
  @override
  State<StatefulWidget> createState() {
    return _ReminderFormState();
  }
  
}

class _ReminderFormState extends State<ReminderForm> {

  Future<List<({ String stpid, String rtid, int? eta })>>? reminderInfoFuture;
  /// ones that have been selected to be added / removed
  Set<String> rtidsToChange = {};
  int reminderThresh = 5;
  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return FutureBuilder(
      future: reminderInfoFuture,
      builder: (context, snapshot) {
        // TODO: 30s timeout
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: Text("Loading"),);
        }
        final dataForAllStops = snapshot.data;
        if (dataForAllStops == null) {
          return Center(child: Column(children: [
            Text("Loading failed!"),
            Text("Error: ${snapshot.error}"),
          ]));
        }
        final dataForThisStop = dataForAllStops.where((x) => x.stpid == widget.stpid);
        final routesToShow = widget.activeRoutes;
        for (final reminder in dataForThisStop) {
          if (routesToShow.contains(reminder.rtid)) {
            continue;
          }
          routesToShow.add(reminder.rtid);
        }
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: routesToShow
                .map((rtid) {
                  final reminderCurrentlyActive = dataForThisStop.map((x) => x.rtid).contains(rtid);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (rtidsToChange.contains(rtid)) {
                          rtidsToChange.remove(rtid);
                        } else {
                          rtidsToChange.add(rtid);
                        }
                      });
                    },
                    child: Column(
                      children: [
                        Text(rtid),
                        Text(reminderCurrentlyActive ? "active" : "inactive"),
                      ] + (rtidsToChange.contains(rtid) ? [Text("marked")] : [])
                    ),
                  );
                })
                .toList(),
            ),
            Slider(
              value: reminderThresh.toDouble(),
              label: reminderThresh.toString(),
              onChanged: (x) {
                setState(() {
                  reminderThresh = x.toInt();
                });
              },
              min: 3.0,
              max: 15.0,
              divisions: 15 - 3 + 1,
            ),
            Text("$dataForThisStop"),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: getColor(context, ColorType.primary)
                ),
              )
            ),
            ElevatedButton(
              onPressed: () async {
                  final modifications = rtidsToChange.map((rtid) {
                    final reminderCurrentlyActive = dataForThisStop.map((x) => x.rtid).contains(rtid);
                    if (reminderCurrentlyActive) {
                      return RemoveReminder(stpid: widget.stpid, rtid: rtid);
                    } else {
                      return AddReminder(stpid: widget.stpid, rtid: rtid, thresh: reminderThresh);
                    }
                  }).toList();

                  try {
                    await IncomingBusReminderService.modifyReminders(modifications);                  
                    Navigator.pop(context);
                    if (!context.mounted) return;
                  } on Exception catch (e) {
                    showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(title: Text("Failed!\n${e.toString()}"))
                    );
                  }
              },
              child: Text(
                "Update",
                style: TextStyle(
                  color: getColor(context, ColorType.primary)
                ),
              )
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await IncomingBusReminderService.sendTestNotification();
                } on Exception catch (e) {
                  print("test notification failed: ${e.toString()}");
                }
              },
              child: Text(
                "Send Test Notification (takes about 10s)",
                style: TextStyle(
                  color: getColor(context, ColorType.primary)
                ),
              )
            ),
          ],
        );
      },
    );
  }
  
  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    reminderInfoFuture ??= IncomingBusReminderService.getActiveReminders();
  }
}
