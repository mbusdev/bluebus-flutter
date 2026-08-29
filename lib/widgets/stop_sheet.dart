import 'dart:async';
import 'package:bluebus/globals.dart';
import 'package:bluebus/providers/bus_provider.dart';
import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/refresh_button.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../constants.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart';
import 'package:intl/intl.dart';
import 'upcoming_stops_widget.dart';

class StopSheet extends StatefulWidget {
  final String stopID;
  final String stopName;
  final bool isFavorite;
  final Future<void> Function(String, String) onFavorite;
  final Future<void> Function(String, String) onUnFavorite;
  final void Function() onGetDirections;
  final void Function(String) showBusSheet;
  final BusProvider busProvider;

  StopSheet({
    Key? key,
    required this.stopID,
    required this.stopName,
    required this.isFavorite,
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
                  RouteIcon.medium(widget.busId),

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
                                  : " • Scheduled",
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
            showSeeMoreButton: (widget.busProvider.containsBus(widget.vehicleId)), // Only show the see more button if the bus is live
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
  
class _StopSheetState extends State<StopSheet> with WidgetsBindingObserver {
  late Future<List<BusWithPrediction>> loadedStopData;
  late bool _isFavorite;
  Timer? _refreshTimer;
  bool _isInBackground = false;

  // for select bus stops with images
  late bool imageBusStop;
  late String imagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadedStopData = fetchStopData(widget.stopID);
    _isFavorite = widget.isFavorite;
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
    
    // Start auto-refresh every 30 seconds
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isInBackground) {
        _refreshData();
      }
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isInBackground = true;
        _stopRefreshTimer();
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        // Refresh immediately when app comes to foreground
        _refreshData();
        _startRefreshTimer();
        break;
      case AppLifecycleState.detached:
        _stopRefreshTimer();
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state if needed
        break;
    }
  }

  void _refreshData() {
    if (!_isInBackground) {
      setState(() {
        loadedStopData = fetchStopData(widget.stopID);
      });
    }
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
              arrivingBuses = snapshot.data!;
              arrivingBuses.sort(
                (lhs, rhs) => (int.tryParse(lhs.prediction) ?? 0).compareTo(int.tryParse(rhs.prediction) ?? 0)
              );
            }

            double initialSize = 0.9;

            if (snapshot.hasData) {
              final itemCount = arrivingBuses.length;

              // edge case
              if (itemCount == 0) {
                if (imageBusStop) {
                  initialSize = 0.8;
                } else {
                  initialSize = 0.5;
                }
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

            double paddingBelowButtons = globalBottomPadding;

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
                                            gradient: getStopHeroImageGradient(context)
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
                                                      RefreshButton(
                                                        loading: snapshot.connectionState == ConnectionState.waiting,
                                                        onTap: _refreshData
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
                                                              Center(
                                                                child: Column(
                                                                  children: [
                                                                    SizedBox(height: 50,),
                                                                    Icon(
                                                                      Icons.no_transfer,
                                                                      size: 80,
                                                                      color: Color.fromARGB(255, 150, 150, 150),
                                                                    ),
                                                                    Text(
                                                                      "no buses arriving",
                                                                      style: TextStyle(
                                                                        color: Color.fromARGB(255, 150, 150, 150),
                                                                        fontWeight: FontWeight.bold
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
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
                                                        "Can't load data. Check your internet connection and try refreshing",
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
                                        getColor(context, ColorType.backgroundGradientStart),  // transparent
                                        Color.lerp(getColor(context, ColorType.backgroundGradientStart),  getColor(context, ColorType.background), 0.5)!, // half-way color
                                        getColor(context, ColorType.background), // full color
                                      ],
                                      stops: [0, 0.4, 1]
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
                                  padding: EdgeInsets.symmetric(horizontal: globalLeftRightPadding),
                                  child: Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context); 
                                          widget.onGetDirections();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                                          backgroundColor: getColor(context, ColorType.importantButtonBackground),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          elevation: 0
                                        ),
                                        icon: Icon(
                                          Icons.directions, 
                                          color: getColor(context, ColorType.importantButtonText),
                                          size: 20,
                                        ), 
                                        label: Text(
                                          'Get Directions',
                                          style: TextStyle(
                                            color: getColor(context, ColorType.importantButtonText),
                                            fontSize: 16, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ), 
                                      ),
                                      
                                      Spacer(),
                                            
                                      ElevatedButton(
                                        onPressed: () {
                                          // Call the appropriate function
                                          if (_isFavorite){
                                            widget.onUnFavorite(widget.stopID, widget.stopName);
                                          } else {
                                            widget.onFavorite(widget.stopID, widget.stopName);
                                          }
                                            
                                          // Update the UI immediately
                                          setState(() {
                                            _isFavorite = !_isFavorite;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: getColor(context, ColorType.secondaryButtonBackground),
                                          shape: CircleBorder(),
                                          shadowColor: Colors.black,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size(0,0),
                                          fixedSize: Size(40,40),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                                          elevation: 0
                                        ),
                                        child: Icon(
                                          (_isFavorite ?? false)?  Icons.favorite : Icons.favorite_border, 
                                          color: (_isFavorite ?? false)? Colors.red : getColor(context, ColorType.secondaryButtonText),
                                          size: 20,
                                        ), 
                                      ),
                    
                                      SizedBox(width: 10,),
                                            
                                      ElevatedButton(
                                        onPressed: () {
                                          if (arrivingBuses.isEmpty) {
                                            return;
                                          }

                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return Dialog(
                                                
                                                backgroundColor: getColor(context, ColorType.background),
                                                
                                                
                                              
                                                constraints: BoxConstraints(
                                                  minWidth: 0.0,
                                                  minHeight: 0.0,
                                                ),
                                                child: ReminderForm(
                                                  stpid: widget.stopID,
                                                  
                                                  activeRoutes: arrivingBuses
                                                    .fold([], (xs, x) => xs.contains(x.id) ? xs : xs + [x.id]),
                                                ),
                                              );
                                            }
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: getColor(context, ColorType.secondaryButtonBackground),
                                          shape: CircleBorder(),
                                          shadowColor: Colors.black,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size(0,0),
                                          fixedSize: Size(40,40),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                                          elevation: 0
                                        ),
                                        child: Icon(
                                          (arrivingBuses.isEmpty)? Icons.notifications_off_outlined : Icons.notifications_none,
                                          color: getColor(context, ColorType.secondaryButtonText),
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
  /// ones that have an active reminder set
  Set<String> activeRtids = {};
  /// ones that have been selected to be added / removed
  Set<String> rtidsToChange = {};
  int reminderThresh = 5;

  // exists to ensure the notification button isn't pressed multiple times 
  // while waiting for the response
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: reminderInfoFuture,
      builder: (context, snapshot) {
        // TODO: 30s timeout

        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 400,
            width: 400,
            child: Center(
              child: SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  color: getColor(context, ColorType.opposite),
                )
              ),
            ),
          );
        }
        
        final activeRemindersForAllStops = snapshot.data;
        if (activeRemindersForAllStops == null) {
          // Wait for the current build frame to finish before showing dialogs/popping
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context);
            
            showMaizebusOKDialog(
              contextIn: context,
              title: "Failed to load reminders",
              content: "Make sure you have the notification permission enabled in settings. If this error is persistent, please send us feedback through the feedback form in the settings page",
            );
          });
          return SizedBox.shrink();
        }
        

        final activeRemindersForThisStop = activeRemindersForAllStops.where((x) => x.stpid == widget.stpid);
        // which icons to show (active reminders + active routes)
        final routesToShow = widget.activeRoutes;

        for (final reminder in activeRemindersForThisStop) {
          activeRtids.add(reminder.rtid);
          if (!routesToShow.contains(reminder.rtid)) {
            routesToShow.add(reminder.rtid);
          }
        }

        return Column(
          spacing: 0,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(25),
              
              child: Column(
                spacing: 0,
                
                children: [
                  Row( //"set notification"
                    children: [
                      Expanded(
                        child: Text(
                          "Set Notification",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Urbanist',
                            color: getColor(context, ColorType.opposite)
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row( //"for bus routes:"
                    children: [
                      Expanded(
                        child: Text(
                          "For these bus routes:",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Urbanist',
                            color: getColor(context, ColorType.opposite)
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap( //icons
                    alignment: WrapAlignment.center,
                    spacing: 0,
                    runSpacing: 0,
                    children: routesToShow.map((rtid) {
                      return Stack(
                        
                        children: [
                          Column(
                            
                            children: [
                              SizedBox(
                                height: 10,
                                width: 60,
                              ),
                              RouteIcon.medium(rtid),
                              
                              Checkbox(
                                value: activeRtids.contains(rtid) != rtidsToChange.contains(rtid),
                                side: BorderSide(
                                  color: getColor(context, ColorType.highlighted)
                                ),
                                activeColor: getColor(context, ColorType.highlighted),
                                onChanged: (_) {},
                              )
                            ]
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                if (rtidsToChange.contains(rtid)) {
                                  rtidsToChange.remove(rtid);
                                } else {
                                  rtidsToChange.add(rtid);
                                }
                              });
                            },
                            child: Container(
                              height: 100,
                              width: 48,
                              color: Colors.transparent
                            )
                          )
                        ]
                      );
                    }).toList()
                  ),
                  Row( //"remind me when:"
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: getColor(context, ColorType.opposite),
                            fontFamily: 'Urbanist',
                            ),
                            children: [
                              TextSpan(
                                text: "Remind me when a bus is\n"
                              ),
                              TextSpan(
                                text: reminderThresh.toString(),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: getColor(context, ColorType.highlighted),
                                  fontFamily: 'Urbanist',
                                ),
                              ),
                              TextSpan(
                                text: " min away"
                              )
                            ]
                          ),
                        
                        ),
                      ),
                    ],
                  ),
                  Slider( //slider
                    activeColor: getColor(context, ColorType.highlighted),

                    value: reminderThresh.toDouble(),
                    label: reminderThresh.toString(),

                    onChanged: (x) {
                      setState(() {
                        reminderThresh = x.toInt();
                      });
                    },
                    min: 3.0,
                    max: 20.0,
                  ),
                ],
              )
            ),
            Padding(
              padding: EdgeInsetsGeometry.only(
                left: 10,
                right: 10,
                bottom: 6
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () async {
                        // is processing lets us make sure no one spams the button
                        setState(() => _isProcessing = true);
                      
                        List<RemindersModification> modifications = [];
                        for (String rtid in routesToShow) {
                          final bool keepOrAdd = rtidsToChange.contains(rtid) != activeRtids.contains(rtid);
                          final bool shouldRemove = rtidsToChange.contains(rtid) && activeRtids.contains(rtid);

                          if (shouldRemove) {
                            modifications.add(RemoveReminder(stpid: widget.stpid, rtid: rtid));
                          }
                          if (keepOrAdd) {
                            modifications.add(AddReminder(stpid: widget.stpid, rtid: rtid, thresh: reminderThresh));
                          }
                        }

                        try {
                          await IncomingBusReminderService.modifyReminders(modifications);                  
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        } on Exception catch (e) {
                          showDialog(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: Text("Failed!\n${e.toString()}")),
                          );
                        }
                        setState(() => _isProcessing = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getColor(context, ColorType.importantButtonBackground),
                      ),
                      child: Text(
                        "Update",
                        style: TextStyle(
                          color: getColor(context, ColorType.importantButtonText),
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                        )
                      ),
                    ),
                  )
                ],
              )
            ),
          ]
        );
      },
    );
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reminderInfoFuture ??= IncomingBusReminderService.getActiveReminders();
  }
}
