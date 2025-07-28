import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/search_bar.dart' as custom_widgets;
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import '../constants.dart';

class JourneySearchPanel extends StatefulWidget {
  const JourneySearchPanel({super.key});

  @override
  State<JourneySearchPanel> createState() => _JourneySearchPanelState();
}

class _JourneySearchPanelState extends State<JourneySearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  bool _isLoadingJourney = false;
  String? _journeyError;

  Map<String, Map<String, double>>? _buildingDict;

  @override
  void initState() {
    super.initState();
    _fetchBuildingLocations();
  }

  Future<void> _fetchBuildingLocations() async {
    try {
      final buildingLocationsUrl = BACKEND_URL + '/getBuildingLocations';
      final response = await http.get(Uri.parse(buildingLocationsUrl));
      if (response.statusCode == 200) {
        final List<dynamic> buildings = json.decode(response.body);
        final dict = <String, Map<String, double>>{};
        for (final b in buildings) {
          final names = [
            b['buildingName'],
            b['abbrev'],
            b['altName'],
            b['address'],
          ];
          for (final name in names) {
            if (name != null && name.toString().trim().isNotEmpty) {
              dict[name.toString().toLowerCase()] = {
                'lat': b['lat'],
                'lon': b['long'],
              };
            }
          }
        }
        print('DEBUG: buildingDict = ' + json.encode(dict)); // Debug print
        if (mounted) {
          setState(() {
            _buildingDict = dict;
          });
        }
      } else {
        if (mounted) _showError('Failed to fetch building locations.');
      }
    } catch (e) {
      if (mounted) _showError('Error fetching building locations: $e');
    }
  }

  Future<Map<String, double>?> _lookupDestination(String query) async {
    if (_buildingDict == null) return null;
    final key = query.trim().toLowerCase();
    return _buildingDict![key];
  }

  Future<void> _onSearch(String query) async {
    setState(() {
      _isLoadingJourney = true;
      _journeyError = null;
    });

    Map<String, double>? origin;
    if (_startController.text.trim().isNotEmpty) {
      origin = await _lookupDestination(_startController.text);
      if (origin == null) {
        setState(() {
          _isLoadingJourney = false;
          _journeyError = 'Start location not found.';
        });
        _showError('Start location not found.');
        return;
      }
    }

    final dest = await _lookupDestination(query);
    if (dest == null) {
      setState(() {
        _isLoadingJourney = false;
        _journeyError = 'Destination not found.';
      });
      _showError('Destination not found.');
      return;
    }

    double originLat, originLon;
    if (origin != null) {
      originLat = origin['lat']!;
      originLon = origin['lon']!;
    } else {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        setState(() {
          _isLoadingJourney = false;
          _journeyError = 'Could not get current location.';
        });
        _showError('Could not get current location.');
        return;
      }
      originLat = position.latitude;
      originLon = position.longitude;
    }

    try {
      final journeys = await JourneyRepository.planJourney(
        originLat: originLat,
        originLon: originLon,
        destLat: dest['lat']!,
        destLon: dest['lon']!,
      );
      setState(() {
        _isLoadingJourney = false;
      });
      if (journeys.isEmpty) {
        setState(() {
          _journeyError = 'No journeys found.';
        });
        _showError('No journeys found.');
      } else {
        _journeyError = null;
        _showResults(journeys);
      }
    } catch (e) {
      setState(() {
        _isLoadingJourney = false;
        _journeyError = 'Failed to fetch journey: $e';
      });
      _showError('Failed to fetch journey: $e');
    }
  }

  void _showResults(List<Journey> journeys) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          constraints: const BoxConstraints(maxHeight: 400),
          child: JourneyResultsWidget(journeys: journeys),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _startController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.my_location),
                                labelText: 'From',
                                hintText: 'Enter start location...',
                                border: const OutlineInputBorder(),
                              ),
                              onSubmitted: (_) {},
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.location_on),
                                labelText: 'To',
                                hintText: 'Enter destination...',
                                border: const OutlineInputBorder(),
                              ),
                              onSubmitted: _isLoadingJourney ? null : (query) { _onSearch(query); },
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingJourney)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}