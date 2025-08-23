import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import '../constants.dart';

class DirectionsSheet extends StatefulWidget {
  final Map<String, double>? origin;
  final Map<String, double>? dest;
  final bool useOrigin;
  final String originName;
  final String destName;
  final void Function(Location, bool) onChangeSelection;
  final void Function(Journey)? onSelectJourney;

  const DirectionsSheet({
    Key? key,
    required this.origin,
    required this.dest,
    required this.useOrigin,
    required this.originName,
    required this.destName,
    required this.onChangeSelection,
    this.onSelectJourney,
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
            return SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
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
