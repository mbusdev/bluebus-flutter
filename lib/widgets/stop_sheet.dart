import 'dart:math';

import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/bus_repository.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bus.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart'; 
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'upcoming_stops_widget.dart';

class StopSheet extends StatefulWidget {
  final String stopID;
  final String stopName;
  final Future<void> Function(String, String) onFavorite;
  final Future<void> Function(String, String) onUnFavorite;
  final void Function() onGetDirections;
  void Function(String) showBusSheet;
  final List<String> routesWithActiveReminder;
  final Future<void> Function(String, String) onToggleReminder;

  StopSheet({
    Key? key,
    required this.stopID,
    required this.stopName,
    required this.onFavorite,
    required this.onUnFavorite,
    required this.onGetDirections,
    required this.showBusSheet,
    required this.routesWithActiveReminder,
    required this.onToggleReminder,
  }) : super(key: key);

  @override
  State<StopSheet> createState() => _StopSheetState();
}
                          
String futureTime(String minutesInFuture){
  int min = int.parse(minutesInFuture);
  DateTime now = DateTime.now();
  DateTime futureTime = now.add(Duration(minutes: min));
  return DateFormat('hh:mm a').format(futureTime);
}

String format(String text) {
  if (text == null || text.isEmpty) {
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

    // return Padding(
    //   padding: const EdgeInsets.symmetric(horizontal: 20),
    //   child: 
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              // behavior: HitTestBehavior.opaque, // Clicking anywhere on the bus opens the upcoming stops list
              onTap: () {
                setState(() {is_expanded = !is_expanded;});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10 ),
                child: Row(
                children: [
                  Container( // Circular icon on the left (with the bus code, e.g. "NW")
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
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
                  
                  SizedBox(width: 15,),
                                          
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getPrettyRouteName(widget.busId) + ": " + widget.vehicleId,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          )
                        ),
                                          
                        Text(
                          (widget.busPrediction != "DUE")? "${format(widget.busDirection)}, est: ${futureTime(widget.busPrediction)}" : "within the next minute",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          )
                        )
                      ],
                    ),
                  ),
                                          
                  (widget.busPrediction != "DUE")?
                  Column(
                    children: [
                      Text(
                        widget.busPrediction,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                          height: 0
                        )
                      ),
                      Text(
                        "min",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 0
                        )
                      )
                    ],
                  ) : SizedBox.shrink(),

                  // IconButton(
                  //   icon: 
                    is_expanded ? Icon(Icons.expand_less) : Icon(Icons.expand_more),
                    // onPressed: () {
                    //   setState(() {is_expanded = !is_expanded;});
                    // },
                  // )
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
              filterAfterPredictionTime: (widget.busPrediction == "DUE") ? 0 : int.parse(widget.busPrediction) - 5, // Minus five minutes to account for prediction time discrepancies
              filterAfterStop: widget.stopId,
              showSeeMoreButton: true,
              showBusSheet: widget.showBusSheet,
              childIfNoUpcomingStopsFound: Padding(
                padding: EdgeInsets.only(left: 55),
                child: Text("No upcoming stops found for this bus", style: TextStyle(fontStyle: FontStyle.italic),),
              ),),

    )
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
  });
}


class _StopSheetState extends State<StopSheet> {
  late Future<(List<BusWithPrediction>, bool)> loadedStopData;
  bool? _isFavorited;
  late List<String> _routesWithActiveReminder;  

  // for select bus stops with images
  late bool imageBusStop;
  late String imagePath;

  @override
  void initState() {
    super.initState();
    _routesWithActiveReminder = widget.routesWithActiveReminder;
    loadedStopData = fetchStopData(widget.stopID);
    imageBusStop = (widget.stopID == "C250") || (widget.stopID == "N406") ||
                   (widget.stopID == "N405") || (widget.stopID == "N550") ||
                   (widget.stopID == "N551") || (widget.stopID == "N553") ||
                   (widget.stopID == "C251");
    if (widget.stopID == "C250"){
      imagePath = "assets/CCTC.jpg";
    }
    if (widget.stopID == "C251"){
      imagePath = "assets/CCTC_Ruthven.jpg";
    }
    if (widget.stopID == "N406"){
      imagePath = "assets/FXB_outbound.jpg";
    }
    if (widget.stopID == "N405"){
      imagePath = "assets/FXB_inbound.jpg";
    }
    if (widget.stopID == "N550"){
      imagePath = "assets/Pierpont.jpg";
    }
    if (widget.stopID == "N551"){
      imagePath = "assets/PierpontBursley.jpg";
    }
    if (widget.stopID == "N553"){
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
            
            if (snapshot.hasData){
              arrivingBuses = snapshot.data!.$1;
              if (_isFavorited == null) {
                _isFavorited = snapshot.data!.$2;
              }
            }

            double initialSize = 0.9;
        
            if (snapshot.hasData) {
              final itemCount = arrivingBuses.length;
        
              // edge case
              if(itemCount == 0){
                // initialSize = 0.4;
                initialSize = 0.5;
              }
              
            } else {
              // A fixed initial size for loading or error states.
              initialSize = 0.4; 
              if (imageBusStop){
                initialSize = 0.6;
              }
            }
        
            return DraggableScrollableSheet(
              initialChildSize: initialSize,
              minChildSize: 0.0, // leave at 0.0 to allow full dismissal
              maxChildSize: 0.9, 
              snap: true, 
              snapSizes: const [0.9], 
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: getColor(context, ColorType.background),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      (imageBusStop)?
                      // Image of bus stop
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        child: ShaderMask(
                          shaderCallback: (rect) {
                            // Creates a linear gradient from opaque black at the top to transparent black at the bottom
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [getColor(context, ColorType.primary), Colors.transparent],
                              stops: [0.7, 1.0],
                            ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                          },
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ) : SizedBox.shrink(),
                  
                      // header
                      Padding(
                        padding: EdgeInsets.only(top:(imageBusStop)? 0 : 20, left: 20, right: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.stopName,
                                // IF YOU CHANGE THIS STYLE make sure to change the estimate
                                // function too (top of this file)
                                style: TextStyle(
                                  fontFamily: 'Urbanist',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 30,
                                  height: 0
                                ),
                              ),
                            ),
                                    
                            SizedBox(width: 15,),
                                    
                            Column(
                              children: <Widget>[
                                IntrinsicWidth(
                                  child: Container(
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        child: MediaQuery(
                                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                                          child: Text(
                                            widget.stopID,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontFamily: 'Urbanist',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                                  
                      SizedBox(height: 20,),
                      
                      // future data
                      Expanded(
                        child: 
                          
                          (snapshot.connectionState == ConnectionState.waiting)? Center(child: const CircularProgressIndicator()) :
                          (snapshot.hasData)? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  (arrivingBuses.length == 0)?
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      "There are currently no departing busses",
                                      style: TextStyle(
                                        fontFamily: 'Urbanist',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ):
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Next bus departures",
                                          style: TextStyle(
                                            fontFamily: 'Urbanist',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 20,
                                          ),
                                        ),
                                              
                                        SizedBox(width: 5,),
                                              
                                        GestureDetector(
                                          onTap: () {
                                            _refreshData();
                                          },
                                          child: Icon(Icons.refresh),
                                        )
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: 10,),
                                                  
                                  Expanded(
                                    child: ListView.separated(
                                      controller: scrollController,
                                      itemCount: arrivingBuses.length,
                                      itemBuilder: (context, index) {
                                        BusWithPrediction bus = arrivingBuses[index];

                                        return ExpandableStopWidget(
                                          routeId: bus.id,
                                          vehicleId: bus.vehicleId,
                                          busId: bus.id,
                                          busPrediction: bus.prediction,
                                          busDirection: bus.direction,
                                          stopId: widget.stopID,
                                          showBusSheet: widget.showBusSheet
                                        );

                                        },
                                        separatorBuilder: (context, index) {
                                          return Divider(
                                            height: 0,
                                            indent: 20,
                                            endIndent: 20,
                                            thickness: 1
                                          );
                                          // return Padding(
                                          //   padding: const EdgeInsets.symmetric(horizontal: 20),
                                          //   child: Divider(),
                                          // );
                                        },
                                      ),
                                  ),
                                  
                                  SizedBox(height: 10,),
                                  
                                  // bottom buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                          shadows: [
                                            Shadow(
                                              color: getColor(context, ColorType.mapButtonShadow),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)
                                            )
                                          ],
                                        ), 
                                        label: Text(
                                          'Get Directions',
                                          style: TextStyle(
                                            color: getColor(context, ColorType.primary),
                                            fontSize: 16, 
                                            fontWeight: FontWeight.w600,
                                            shadows: [
                                              Shadow(
                                                color: getColor(context, ColorType.mapButtonShadow),
                                                blurRadius: 4,
                                                offset: Offset(0, 2)
                                              )
                                            ],
                                          ),
                                        ), 
                                      ),
                                            
                                      ElevatedButton.icon(
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
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                        ),
                                        icon: Icon(
                                          (_isFavorited ?? false)?  Icons.favorite : Icons.favorite_border, 
                                          color: (_isFavorited ?? false)? Colors.red : getColor(context, ColorType.opposite),
                                          size: 20,
                                          shadows: [
                                            Shadow(
                                              color: getColor(context, ColorType.mapButtonShadow),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)
                                            )
                                          ],
                                        ), 
                                        label: Text(
                                          (_isFavorited ?? false)?  'Remove Favorite' : 'Add to Favorites',
                                          style: TextStyle(
                                            color: getColor(context, ColorType.opposite),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            shadows: [
                                              Shadow(
                                                color: getColor(context, ColorType.mapButtonShadow),
                                                blurRadius: 4,
                                                offset: Offset(0, 2)
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                      RemindersButton(
                                        incomingBusRoutes: arrivingBuses.map((bus) => bus.id).toList(),
                                        activeReminderRoutes: _routesWithActiveReminder,
                                        onToggleReminder: (route) async {
                                          await widget.onToggleReminder(widget.stopID, route);
                                          setState(() {
                                            if (_routesWithActiveReminder.contains(route)) {
                                              _routesWithActiveReminder.remove(route);
                                            } else {
                                              _routesWithActiveReminder.add(route);
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                                  
                                  (MediaQuery.of(context).padding.bottom == 0.0)?
                                  SizedBox(height: 20,) : SizedBox(height: MediaQuery.of(context).padding.bottom,)
                                ],
                              )
                              
                              : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                    "There doesn't seem to be any departure data for this stop",
                                    style: TextStyle(
                                      fontFamily: 'Urbanist',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 20,
                                    ),
                                  ),
                              )
                      ),
                    ],
                  )
                );
              }
            );
          }
        ),
      ],
    );
  }
}

class RemindersButton extends StatelessWidget {
  const RemindersButton({
    super.key,
    required this.activeReminderRoutes,
    required this.incomingBusRoutes,
    required this.onToggleReminder,
  });

  final List<String> activeReminderRoutes;
  final List<String> incomingBusRoutes;
  final Future<void> Function(String) onToggleReminder;
  
  @override
  Widget build(BuildContext context) {
    final routesList = [];
    for (final route in incomingBusRoutes) {
      if (!routesList.contains(route)) {
        routesList.add(route);
      }
    }
    for (final route in activeReminderRoutes) {
      if (!routesList.contains(route)) {
        routesList.add(route);
      }
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 9),
      child: MenuAnchor(
        style: MenuStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.only(bottom: 18 + 5, top: 5)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorderWithTail(cornerRadius: 20.0),
          ),
          alignment: Alignment(0, 1),
          backgroundColor: WidgetStatePropertyAll(Colors.white),
        ),
        alignmentOffset: Offset(-29, 0),
        menuChildren: routesList.map((route) {
          var color = RouteColorService.getRouteColor(route);
          if (!activeReminderRoutes.contains(route)) {
            color = Color.from(
              alpha: 0.5,
              red: color.r,
              green: color.g,
              blue: color.b,
            );
          }
          return Padding(
            padding: EdgeInsetsGeometry.symmetric(vertical: 5, horizontal: 9),
            child: GestureDetector(
              onTap: () {
                onToggleReminder(route);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // color: RouteColorService.getRouteColor(route),
                  color: color,
                ),
                alignment: Alignment.center,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.0)),
                  child: Text(
                    route,
                    style: TextStyle(
                      color: RouteColorService.getContrastingColor(route),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        builder:
            (BuildContext context, MenuController controller, Widget? child) =>
                ElevatedButton(
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(CircleBorder())
                  ),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                    NotificationService.requestPermission();
                    // NotificationService.sendPushNotification();
                    //NotificationService.sendNotification();
                  },
                  child: Icon(Icons.notifications_none, size: 20),
                ),
      ),
    );
  }
}

class RoundedRectangleBorderWithTail extends OutlinedBorder {
  const RoundedRectangleBorderWithTail({required this.cornerRadius});

  final double cornerRadius;
  
  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    // TODO: actually care about side
    return this;
  }

  @override
  Path getInnerPath(Rect rect, {ui.TextDirection? textDirection}) {
    Path p = Path();
    p.addRRect(
      RRect.fromRectXY(
        Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - 18),
        cornerRadius,
        cornerRadius
      )
    );
    // tail
    final ax = rect.left + rect.width / 2 - 9;
    final ay = rect.bottom - 18;
    p.moveTo(ax + 9, ay + 15);
    p.cubicTo(
      ax + 9, ay + 11.5,
      ax + 5.25, ay + 0,
      ax + 0, ay + 0
    );
    p.relativeLineTo(18, 0);
    p.cubicTo(ax + 12.375, ay + 0, ax + 9, ay + 11.5, ax + 9, ay + 15);
    p.close();
    
    return p;
  }

  @override
  Path getOuterPath(Rect rect, {ui.TextDirection? textDirection}) {
    return getInnerPath(rect, textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {ui.TextDirection? textDirection}) {
    // do nothing since the reminders thing only needs drop shadow
    // Paint paint = Paint();
    // paint.style = PaintingStyle.stroke;
    // paint.strokeWidth = 2;
    // canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }

  @override
  ShapeBorder scale(double t) {
    return this;
  }
  
}
