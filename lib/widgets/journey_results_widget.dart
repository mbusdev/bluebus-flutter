import 'package:bluebus/globals.dart';
import 'package:bluebus/widgets/upcoming_stops_widget.dart';
import 'package:flutter/material.dart';
import '../models/journey.dart';
import '../constants.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import '../services/route_color_service.dart';
import 'package:intl/intl.dart';

int getSecondsAfterMidnightUtc() {
  // Get the current time in UTC
  DateTime nowUtc = DateTime.now().toUtc();

  DateTime beginningOfDayUtc = DateTime.utc(
    nowUtc.year,
    nowUtc.month,
    nowUtc.day,
  );

  Duration difference = nowUtc.difference(beginningOfDayUtc);
  return difference.inSeconds;
}

// takes time from seconds after midnight and converts to clock time
String formatSecondsToTime(int utcSeconds) {
  // get the current date in UTC to serve as a reference
  final nowUtc = DateTime.now().toUtc();

  // create a DateTime object for "Midnight UTC" today
  final midnightUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

  // add the seconds to midnight
  final specificTimeUtc = midnightUtc.add(Duration(seconds: utcSeconds));

  // convert to the device's Local time zone
  final localTime = specificTimeUtc.toLocal();

  // format it (h:mm a handles 12-hour format and AM/PM)
  return DateFormat('h:mm a').format(localTime);
}


// helper class to display legs with expanded property
class LegToDisplay {
  final String origin;
  final String destination;
  final double duration;
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
    required this.destinationID,
  });
}

class JourneyResultsWidget extends StatefulWidget {
  final List<Journey> journeys;
  final String start;
  final String end;
  final Map<String, double>? origin;
  final Map<String, double>? dest;
  final void Function(Location, bool) onChangeSelection;
  final void Function(Journey)? onSelectJourney;
  final ScrollController? scrollController;

  const JourneyResultsWidget({
    super.key,
    required this.journeys,
    required this.start,
    required this.end,
    required this.origin,
    required this.dest,
    required this.onChangeSelection,
    this.onSelectJourney,
    required this.scrollController
  });

  @override
  State<JourneyResultsWidget> createState() => _JourneyResultsWidgetState();
}

class _JourneyResultsWidgetState extends State<JourneyResultsWidget> {
  int _selectedIndex = 0;
  bool _autoSelected = false;

  @override
  void initState() {
    super.initState();
    // Autoselect the top (first) journey and notify parent once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoSelected && widget.journeys.isNotEmpty) {
        _autoSelected = true;
        widget.onSelectJourney?.call(widget.journeys[0]);
        setState(() {
          _selectedIndex = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Prebuild journey cards list so the tree is cleaner and avoids deep inline closures
    final List<Widget> journeyWidgets = widget.journeys.asMap().entries.map((
      entry,
    ) {
      final idx = entry.key;
      final Journey journey = entry.value;
      final totalDuration = journey.arrivalTime - getSecondsAfterMidnightUtc();

      Set<String> busIDs = {};
      for (Leg l in journey.legs) {
        if (l.rt != null) busIDs.add(l.rt!);
      }

      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = idx;
          });
          widget.onSelectJourney?.call(journey);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              getInfoCardShadow(context)
            ],
            color: (_selectedIndex == idx)
              ? getColor(context, ColorType.infoCardHighlighted)
              : getColor(context, ColorType.infoCardColor),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: (value) {
                // lets this also change the selected index when you expand the tile by 
                // tapping the expansion icon, not just when you tap the whole card
                setState(() {
                  _selectedIndex = idx;
                });
                widget.onSelectJourney?.call(journey);
              },
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(totalDuration / 60).round()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                      height: 0,
                    ),
                  ),
                  Text(
                    ' min',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 25,
                      height: 1.5,
                    ),
                  ),
                  Spacer(),
                  Text(
                    (busIDs.isEmpty) ? '' : 'via ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 25,
                      height: 1.5,
                    ),
                  ),
                  ...busIDs.map((busID) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6, right: 6),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RouteColorService.getRouteColor(busID),
                        ),
                        alignment: Alignment.center,
                        child: MediaQuery(
                          // media query prevents text scaling
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
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
                      ),
                    );
                  }),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: JourneyBody(journey: journey),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: getColor(context, ColorType.background),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),

            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location, size: 25),

                      SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (BuildContext context) {
                                return SearchSheet(
                                  onSearch: (Location location, isStop, id) {
                                    final searchCoordinates = location.latlng;
                                    // null-proofing
                                    if (searchCoordinates != null) {
                                      Navigator.pop(context);
                                      widget.onChangeSelection(location, true);
                                    } else {
                                      print(
                                        "Error: The selected location '${location.name}' has no coordinates.",
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            alignment: Alignment.centerLeft,
                            height: 40,
                            decoration: BoxDecoration(
                              color: getColor(context, ColorType.inputBackground),
                              borderRadius: BorderRadius.all(Radius.circular(20),),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15, right: 15,),
                              child: Text(
                                widget.start,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 0,
                                  color: getColor(context, ColorType.inputText)
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 13,),

                  Row(
                    children: [
                      Icon(Icons.location_on, size: 25),

                      SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (BuildContext context) {
                                return SearchSheet(
                                  onSearch: (Location location, isStop, id) {
                                    final searchCoordinates = location.latlng;
                                    // null-proofing
                                    if (searchCoordinates != null) {
                                      Navigator.pop(context);
                                      widget.onChangeSelection(location, false);
                                    } else {
                                      print(
                                        "Error: The selected location '${location.name}' has no coordinates.",
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            alignment: Alignment.centerLeft,
                            height: 40,
                            decoration: BoxDecoration(
                              color: getColor(context, ColorType.inputBackground),
                              borderRadius: BorderRadius.all(Radius.circular(20),),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15, right: 15,),
                              child: Text(
                                widget.end,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 0,
                                  color: getColor(context, ColorType.inputText)
                                ),
                                overflow: TextOverflow.ellipsis,
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
          ),

          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Text(
              "Options",
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 30,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            child: Column(children: journeyWidgets),
          ),
        ],
      ),
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
        destinationID: leg.destinationID,
      );
    }).toList();
  }

  //function to get intermediary stops between start and end
  (bool, List<(String,int)>) intermediaryBusStops(
    String orgID,
    String desID,
    int legID,
  ) {
    bool foundStart = false;
    List<(String,int)> stopIDs = [];

    // todo: add check for .trip being null
    for (StopTime st in widget.journey.legs[legID].trip!.stopTimes) {
      if (st.stop == orgID) {
        foundStart = true;
      }

      if (st.stop == desID) {
        stopIDs.add((st.stop, st.departureTime));
        return (true, stopIDs);
      }

      if (foundStart) {
        stopIDs.add((st.stop, st.departureTime));
      }
    }

    return (false, []);
  }

  List<ArrivalTimeLocation> intermediaryLocations(String orgId, String desId, int legId) {
    (bool, List<(String, int)>) intermediary_stop_data = intermediaryBusStops(orgId, desId, legId);

    List<ArrivalTimeLocation> outputLocations = [];

    for ((String,int) stopId in intermediary_stop_data.$2) {
      Location? loc = getLocationFromID(stopId.$1);
      if (loc != null) outputLocations.add(ArrivalTimeLocation(formatSecondsToTime(stopId.$2), loc));
    }

    return outputLocations;
  }

  // utc secs after midnight -> michigan time
  String convertSecondsToFormattedTime(int secondsFromMidnightUtc) {
    final now = DateTime.now().toUtc();
    final midnightUtc = DateTime.utc(now.year, now.month, now.day);
    final timeUtc = midnightUtc.add(Duration(seconds: secondsFromMidnightUtc));

    // Convert the UTC time to the local timezone.
    final localTime = timeUtc.toLocal();

    // Use the DateFormat class to format the local time string.
    return DateFormat('h:mm a').format(localTime);
  }

  // returns when the bus is arriving at this stop (used for navigation)
  String? busArrivalAtStop(
    String orgID,
    int legID,
  ) {
    // TODO: add check for .trip being null
    for (StopTime st in widget.journey.legs[legID].trip!.stopTimes) {
      if (st.stop == orgID) {
        return convertSecondsToFormattedTime(st.arrivalTime);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // map each leg
        ...legsToDisplay.map((leg) {
          int index = legsToDisplay.indexOf(leg);

          // walk or bus?
          if (leg.rt == null) {
            // walk
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.directions_walk, size: 40),

                  SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Walk",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 0,
                              ),
                            ),
                          ],
                        ),

                        Text(
                          "to ${getStopNameFromID(leg.destinationID)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 0,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  Text(
                    "${(leg.duration / 60).round()} min",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              
              child: Column(
                children: [
                  Row(
                    children: [
                      // icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RouteColorService.getRouteColor(leg.rt!),
                        ),
                        alignment: Alignment.center,
                        child: MediaQuery(
                          // media query prevents text scaling
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
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
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          "Take ${getPrettyRouteName(leg.rt!)}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),

                      Text(
                        "${busArrivalAtStop(leg.originID,index)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  UpcomingStopsWidget(
                      color: RouteColorService.getRouteColor(leg.rt!),
                      routeId: leg.rt!,
                      vehicleId: leg.trip!.vid,
                      stopsToDisplayOverride: intermediaryLocations(leg.originID, leg.destinationID, index),
                      isExpanded: true,
                      showSeeMoreButton: false,
                      showAbridgedStops: false,
                      routeCodeOverride: leg.rt,
                      childIfNoUpcomingStopsFound: Text("No stops found")
                  ),
                ],
              )
            );
          }
        }),
      ],
    );
  }
}
