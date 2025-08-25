import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import '../constants.dart';

class DirectionsSheet extends StatefulWidget {
  final Map<String, double>? origin;
  final Map<String, double>? dest;
  final bool useOrigin;
  final String originName;
  final String destName;
  final void Function(Location, bool) onChangeSelection;
  final void Function(Journey)? onSelectJourney;
  final void Function(Map<String, double>, Map<String, double>)? onResolved;

  const DirectionsSheet({
    Key? key,
    required this.origin,
    required this.dest,
    required this.useOrigin,
    required this.originName,
    required this.destName,
    required this.onChangeSelection,
    this.onSelectJourney,
    this.onResolved,
  }) : super(key: key);

  @override
  State<DirectionsSheet> createState() => _DirectionsSheetState();
}

class _DirectionsSheetState extends State<DirectionsSheet> {
  late Future<List<Journey>> _listOfJourneys;

  @override
  void initState() {
    super.initState();
    _listOfJourneys = _loadJourneys();
  }

  Future<List<Journey>> _loadJourneys() async {
    double originLat, originLon;

    if (widget.useOrigin) {
      originLat = widget.origin!['lat']!;
      originLon = widget.origin!['lon']!;
    } else {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        throw Exception('Location Error');
      }
      originLat = position.latitude;
      originLon = position.longitude;
    }

    try {
      final journeys = await JourneyRepository.planJourney(
        originLat: originLat,
        originLon: originLon,
        destLat: widget.dest!['lat']!,
        destLon: widget.dest!['lon']!,
      );

      // Inform parent about the resolved origin/dest coordinates
      try {
        widget.onResolved?.call(
          {'lat': originLat, 'lon': originLon},
          {'lat': widget.dest!['lat']!, 'lon': widget.dest!['lon']!},
        );
      } catch (_) {}

      if (journeys.isEmpty) {
        throw Exception('No journeys were found for this route.');
      } else {
        return journeys;
      }
    } catch (e) {
      throw Exception('Failed to fetch journey plans: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: FutureBuilder(
        future: _listOfJourneys,
        builder: (context, journeyload) {
          if (journeyload.connectionState == ConnectionState.waiting) {

            // If loading, return empty sheet...
            return Column(
              mainAxisSize: MainAxisSize.min,
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
                                        onSearch: (Location location, isStop, id) {
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
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 235, 235, 235),
                                    borderRadius: BorderRadius.all(Radius.circular(10)
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10, right: 10),
                                    child: Text(
                                      widget.originName,
                                      style:  TextStyle(
                                        fontSize: 18,
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
                                        onSearch: (Location location, isStop, id) {
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
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 235, 235, 235),
                                    borderRadius: BorderRadius.all(Radius.circular(10)
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10, right: 10),
                                    child: Text(
                                      widget.destName,
                                      style:  TextStyle(
                                        fontSize: 18,
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
                  padding: const EdgeInsets.only(top: 30, bottom: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              ],
            );
          } else if (journeyload.hasData) {
            final journeys = journeyload.data!;

            return JourneyResultsWidget(
              journeys: journeys,
              start: widget.originName,
              end: widget.destName,
              origin: widget.origin,
              dest: widget.dest,
              onChangeSelection: widget.onChangeSelection,
              onSelectJourney: widget.onSelectJourney,
            );
          } else if (journeyload.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${journeyload.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Something went wrong. Contact ishaniik@umich.edu if persistent.',
              ),
            );
          }
        },
      ),
    );
  }
}
