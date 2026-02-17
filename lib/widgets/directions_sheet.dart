import 'package:bluebus/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import '../constants.dart';

class LocationError implements Exception {
  const LocationError();
}
class NotInAnnArborError implements Exception {
  const NotInAnnArborError();
}

class DirectionsSheet extends StatefulWidget {
  final Map<String, double>? origin;
  final Map<String, double>? dest;
  final bool useOrigin;
  final String originName;
  final String destName;
  final void Function(Location, bool) onChangeSelection;
  final void Function(Journey)? onSelectJourney;
  final void Function(Map<String, double>, Map<String, double>)? onResolved;final ScrollController? scrollController;


  const DirectionsSheet({
    Key? key,
    required this.origin,
    required this.dest,
    required this.useOrigin,
    required this.originName,
    required this.destName,
    required this.onChangeSelection,
    required this.scrollController, 
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
      } catch(e){
        throw const LocationError();
      }
      // check if you're in ann arbor
      if ((position.latitude > 42.238948) && (position.latitude < 42.327619) &&
          (position.longitude > -83.793253) && (position.longitude < -83.680937) ){
        // we good
      } else {
        throw const NotInAnnArborError();
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: getColor(context, ColorType.background),
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
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: getColor(context, ColorType.inputBackground),
                                      borderRadius: BorderRadius.all(Radius.circular(20)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 15, right: 15),
                                      child: Text(
                                        widget.originName,
                                        style:  TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w400,
                                          height: 0,
                                          color: getColor(context, ColorType.inputText)
                                        ),
                                        overflow: TextOverflow.ellipsis
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
      
                          SizedBox(height: 13,),
                      
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
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: getColor(context, ColorType.inputBackground),
                                      borderRadius: BorderRadius.all(Radius.circular(20)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 15, right: 15),
                                      child: Text(
                                        widget.destName,
                                        style:  TextStyle(
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
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                      ),
                    ),
                  ),
      
                  Padding(
                    padding: const EdgeInsets.only(top: 30, bottom: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: getColor(context, ColorType.opposite)
                      )
                    ),
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
                scrollController: widget.scrollController,
              );
            } else if (journeyload.hasError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;

                Navigator.of(context).pop();

                if (journeyload.error is LocationError) {
                showMaizebusOKDialog(
                  contextIn: context,
                  title: const Text("Location Error"),
                  content: const Text("Please make sure you have location permissions enabled in settings before trying to get directions"),
                );
                } else if (journeyload.error is NotInAnnArborError) {
                  showMaizebusOKDialog(
                    contextIn: context,
                    title: const Text("Not in Ann Arbor"),
                    content: const Text("Please make sure you are in Ann Arbor before trying to get on-campus bus directions"),
                  );
                } else {
                  showMaizebusOKDialog(
                    contextIn: context,
                    title: const Text("Unknown Error"),
                    content: const Text("An unknown error occurred while trying to get directions. Please contact contact@maizebus.com if this persists."),
                  );
                }
              });

              return SizedBox.shrink();
            } else {
              return const Center(
                child: Text(
                  'Something went wrong. Contact contact@maizebus.com if persistent.',
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
