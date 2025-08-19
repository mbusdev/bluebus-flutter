import 'package:bluebus/globals.dart';
import 'package:flutter/material.dart';
import '../models/journey.dart';
import '../constants.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import '../services/route_color_service.dart';


// helper class to display legs with expanded property
class LegToDisplay {
  final String origin;
  final String destination;
  final int duration;
  final int startTime;
  final int endTime;
  final List<StopTime>? stopTimes;
  final Trip? trip;
  final String? rt;
  final String originID;
  final String destinationID;

  bool expanded = false;

  LegToDisplay({
    required this.origin,
    required this.destination,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.stopTimes,
    this.trip,
    this.rt,
    required this.originID,
    required this.destinationID
  });
}


class JourneyResultsWidget extends StatefulWidget {
  final List<Journey> journeys;
  final String start;
  final String end;
  final Map<String, double>? origin;
  final Map<String, double>? dest;
  final void Function(Location, bool) onChangeSelection;

  const JourneyResultsWidget({
    super.key, 
    required this.journeys,
    required this.start,
    required this.end,
    required this.origin,
    required this.dest,
    required this.onChangeSelection
  });

  @override
  State<JourneyResultsWidget> createState() => _JourneyResultsWidgetState();
}

class _JourneyResultsWidgetState extends State<JourneyResultsWidget> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(95, 187, 187, 187), 
                  spreadRadius: 2, 
                  blurRadius: 6, 
                  offset: Offset(0, 3), 
                ),
              ],
            ),

            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 25,
                      ),

                      SizedBox(width: 12,),

                      Expanded(
                        child: GestureDetector(
                          onTap: () { 

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (BuildContext context) {
                                return SearchSheet(
                                  onSearch: (Location location) {
                                    final searchCoordinates = location.latlng;
                                    // null-proofing
                                    if (searchCoordinates != null) {
                                      Navigator.pop(context);
                                      widget.onChangeSelection(location, true);
                                    } else {
                                      print("Error: The selected location '${location.name}' has no coordinates.");
                                    }
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            alignment: Alignment.centerLeft,
                            height: 27,
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 235, 235, 235),
                              borderRadius: BorderRadius.all(Radius.circular(10)
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10, right: 10),
                              child: Text(
                                widget.start,
                                style:  TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 0
                                ),
                                overflow: TextOverflow.ellipsis
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),

                  SizedBox(height: 10,),
              
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 25,
                      ),

                      SizedBox(width: 12,),

                      Expanded(
                        child: GestureDetector(
                          onTap: () { 
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (BuildContext context) {
                                return SearchSheet(
                                  onSearch: (Location location) {
                                    final searchCoordinates = location.latlng;
                                    // null-proofing
                                    if (searchCoordinates != null) {
                                      Navigator.pop(context);
                                      widget.onChangeSelection(location, false);
                                    } else {
                                      print("Error: The selected location '${location.name}' has no coordinates.");
                                    }
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            alignment: Alignment.centerLeft,
                            height: 27,
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 235, 235, 235),
                              borderRadius: BorderRadius.all(Radius.circular(10)
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10, right: 10),
                              child: Text(
                                widget.end,
                                style:  TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 0
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right:20),
            child: Text(
              "Options",
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 30,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 20, right:20),
            child: Column(
              children: widget.journeys.map((Journey journey) {
                final totalDuration = journey.arrivalTime - journey.departureTime;
                final numTransfers = journey.legs.length - 1;
            
                Set<String> busIDs = {};
            
                // get all bus ids for header
                for (Leg l in journey.legs){
            
                  if (l.rt != null){
                    busIDs.add(l.rt!);
                  }
                }
                
                return Card(
                  // rounded corners and shadow.
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  color: Color.fromARGB(255, 240, 240, 240),
            
                  // theme widget to override the default divider color.
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(totalDuration / 60).round()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 40,
                              height: 0
                            ),
                          ),
                          Text(
                            ' min',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 25,
                              height: 1.5
                            ),
                          ),
            
                          Spacer(),
            
                          Text(
                            'via ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 25,
                              height: 1.5
                            ),
                          ),
            
                          ...busIDs.map((busID) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: RouteColorService.getRouteColor(busID), 
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    busID,
                                    style: TextStyle(
                                      color: RouteColorService.getContrastingColor(busID), 
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            );
                          }),
            
                          
                        ],
                      ),
            
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16),
                          child: JourneyBody(journey: journey),
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      )
    );
  }
}

class JourneyBody extends StatefulWidget {
  final Journey journey;
  const JourneyBody({super.key, required this.journey});

  @override
  State<JourneyBody> createState() => _JourneyBodyState();
}

class _JourneyBodyState extends State<JourneyBody> {
  late List<LegToDisplay> legsToDisplay;
  void initState() {
    super.initState();
    // Initialize the list of legs from the journey prop
    legsToDisplay = widget.journey.legs.map((leg) {
      return LegToDisplay(
          origin: leg.origin,
          destination: leg.destination,
          duration: leg.duration,
          startTime: leg.startTime,
          endTime: leg.endTime,
          stopTimes: leg.stopTimes,
          trip: leg.trip,
          rt: leg.rt,
          originID: leg.originID,
          destinationID: leg.destinationID
        );
    }).toList();
  }

  //function to get intermediary stops between start and end
  (bool, List<String>) intermediaryBusStops(String orgID, String desID, int legID){
    
    bool foundStart = false;
    List<String> stopIDs = [];

    // todo: add check for .trip being null
    for(StopTime st in widget.journey.legs[legID].trip!.stopTimes){
      if (st.stop == orgID){
        foundStart = true;
      }

      if (st.stop == desID){
        stopIDs.add(st.stop);
        return (true, stopIDs);
      }

      if (foundStart){
        stopIDs.add(st.stop);
      }
    }

    return (false, []);
  }

  @override
  Widget build(BuildContext context){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // map each leg
        ...legsToDisplay.map((leg) {
          int index = legsToDisplay.indexOf(leg);

          // walk or bus?
          if (leg.rt == null){
            // walk
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.directions_walk,
                    size: 40,
                  ),

                  SizedBox(width: 10,),
              
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Walk",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 0
                          ),
                        ),
                        Text(
                          "to ${getStopNameFromID(leg.destinationID)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 0
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RouteColorService.getRouteColor(leg.rt!), 
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      leg.rt!,
                      style: TextStyle(
                        color: RouteColorService.getContrastingColor(leg.rt!), 
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(width: 10,),
              
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Take ${getPrettyRouteName(leg.rt!)}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 0
                          ),
                        ),

                        // if expanded show full list, otherwise dont lol
                        leg.expanded?
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // list all the intermediary bus stops
                            ...intermediaryBusStops(leg.originID, leg.destinationID, index).$2.map((id){

                              // get index of this stop
                              // TODO: I don't like running this function thrice, but like what's a clean way to do it?
                              int indexId = intermediaryBusStops(leg.originID, leg.destinationID, index).$2.indexOf(id);
                              int len = intermediaryBusStops(leg.originID, leg.destinationID, index).$2.length;

                              return Padding(
                                // conditional padding (to separate get on and get off stops)
                                padding: (indexId == 0)? EdgeInsets.only(bottom: 7) : (indexId == len - 1)? EdgeInsets.only(top: 7) : EdgeInsets.zero,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // conditional icon
                                    (indexId == 0)? Icon(Icons.login) : 
                                    (indexId == len - 1)? Icon(Icons.logout) : 
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5, left: 7, right: 7),
                                      child: Icon(
                                        Icons.fiber_manual_record,
                                        size: 10,
                                        color: Color.fromARGB(50, 0, 0, 0),
                                      ),
                                    ),
                                
                                    SizedBox(width: 10,),
                                
                                    // conditional size and padding for text
                                    ((indexId == 0) || (indexId == len - 1))?
                                    Expanded(
                                      child: Text(
                                        getStopNameFromID(id),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    )
                                    :
                                    Expanded(
                                      child: Text(
                                        getStopNameFromID(id),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }),

                            SizedBox(height: 10,),

                            GestureDetector(
                              onTap: () {     
                                setState(() { 
                                  leg.expanded = false;
                                });
                              },
                              child: Text(
                                "hide",
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color.fromARGB(255, 0, 0, 255)
                                )
                              ),
                            ),
                          ],
                        ) 
                        :
                        // leg not expanded
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.login),
                                SizedBox(width: 10,),
                                Expanded(
                                  child: Text(
                                    getStopNameFromID(leg.originID),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            GestureDetector(
                              onTap: () {     
                                setState(() { 
                                  leg.expanded = true;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 5, bottom: 5),
                                child: Text(
                                  "show intermediate",
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color.fromARGB(255, 0, 0, 255)
                                  )
                                ),
                              ),
                            ),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 10,),
                                Expanded(
                                  child: Text(
                                    getStopNameFromID(leg.destinationID),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ) 

                      ],
                    ),
                  )
                ],
              ),
            );
          }
        }),
      ],
    );
  }
}