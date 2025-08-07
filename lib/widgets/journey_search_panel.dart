import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoadingJourney = false;
  String? _journeyError;

  Map<String, Map<String, double>>? _buildingDict;

  @override
  void initState() {
    super.initState();
    _fetchBuildingLocations();
  }

  @override
  void dispose() {
    _startController.dispose();
    _searchController.dispose();
    _startFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 12.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            LocationSearchBar(
                              controller: _startController,
                              focusNode: _startFocusNode,
                              onLocationSelected: (location) {
                                setState(() {
                                  _startController.text = location.name;
                                });
                              },
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.my_location),
                                labelText: 'From',
                                hintText: 'Enter start location...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LocationSearchBar(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onLocationSelected: (location) {
                                setState(() {
                                  _searchController.text = location.name;
                                });
                                if (!_isLoadingJourney) {
                                  _onSearch(location.name);
                                }
                              },
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.location_on),
                                labelText: 'To',
                                hintText: 'Enter destination...',
                                border: OutlineInputBorder(),
                              ),
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

class LocationSearchBar extends HookWidget {
  final void Function(Location) onLocationSelected;
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;

  const LocationSearchBar({
    super.key,
    required this.onLocationSelected,
    required this.controller,
    required this.focusNode,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final showSuggestions = useState(false);
    useEffect(() {
      void listener() {
        if (!focusNode.hasFocus) {
          showSuggestions.value = false;
        }
      }

      focusNode.addListener(listener);
      return () => focusNode.removeListener(listener);
    }, [focusNode]);
    final searchQuery = useState('');

    final locations = useMemoized(() async {
      try {
        final uri = Uri.parse(BACKEND_URL + '/getBuildingLocations');
        final response = await http.get(uri);

        if (response.statusCode != 200 ||
            response.body.trim() == '{}' ||
            response.body.trim().isEmpty) {
          return <Location>[];
        }

        final buildingLocations = jsonDecode(response.body) as List<dynamic>;
        return buildingLocations.map((building) {
          final name = building['buildingName'] as String;
          final abbrev = building['abbrev'] as String?;
          final altName = building['altName'] as String?;
          final lat = building['lat'] as double;
          final long = building['long'] as double;

          return Location(
            name,
            (abbrev != null)? abbrev : "",
            [if (abbrev != null) abbrev, if (altName != null) altName],
            false,
            latlng: LatLng(lat, long),
          );
        }).toList();
      } catch (e) {
        print('Failed to fetch building locations: $e');
        return <Location>[];
      }
    }, []);

    Map<String, Set<Location>> buildNgramIndex(
      List<Location> locations, {
      List<int> ngramSizes = const [2, 3, 4],
    }) {
      final Map<String, Set<Location>> index = {};
      for (final loc in locations) {
        final name = loc.name.toLowerCase();
        final alias = loc.aliases.map((a) => a.toLowerCase()).join(' ');
        final seen = <String>{};

        for (final n in ngramSizes) {
          for (int i = 0; i <= name.length - n; i++) {
            final ngram = name.substring(i, i + n);
            if (seen.add(ngram)) index.putIfAbsent(ngram, () => {}).add(loc);
          }
          for (int i = 0; i <= alias.length - n; i++) {
            final ngram = alias.substring(i, i + n);
            if (seen.add(ngram)) index.putIfAbsent(ngram, () => {}).add(loc);
          }
        }
      }
      return index;
    }

    List<Location> ngramSearch(String query, Map<String, Set<Location>> index) {
      query = query.toLowerCase().trim();
      if (query.length < 2) return [];

      final sizes = query.length == 2
          ? [2]
          : query.length == 3
          ? [2, 3]
          : [2, 3, 4];
      final seen = <String>{};
      final score = <Location, int>{};

      for (final n in sizes) {
        for (int i = 0; i <= query.length - n; i++) {
          final ngram = query.substring(i, i + n);
          if (seen.add(ngram)) {
            final matches = index[ngram];
            if (matches != null) {
              for (final loc in matches) {
                score[loc] = (score[loc] ?? 0) + 1;
              }
            }
          }
        }
      }

      final total = seen.length;
      final minScore = (0.2 + 0.08 * (query.length - 2)).clamp(0.2, 0.8);

      final filtered = score.entries
          .map((e) => MapEntry(e.key, e.value / total))
          .where((e) => e.value >= minScore)
          .toList();
      filtered.sort((a, b) => b.value.compareTo(a.value));
      return filtered
          .take(score.length.clamp(0, 10).toInt())
          .map((e) => e.key)
          .toList();
    }

    final ngramIndex = useMemoized(() async {
      final locs = await locations;
      return buildNgramIndex(locs);
    }, []);

    final results = useMemoized(() async {
      final idx = await ngramIndex;
      return ngramSearch(searchQuery.value, idx);
    }, [searchQuery.value]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: decoration,
          onChanged: (val) {
            searchQuery.value = val;
            showSuggestions.value = true;
          },
          onSubmitted: (val) async {
            final idx = await ngramIndex;
            final matches = ngramSearch(val, idx);

            if (matches.isNotEmpty) {
              final selected = matches.first;
              controller.text = selected.name;
              onLocationSelected(
                selected,
              ); // triggers _onSearch if it's the "To" field
              showSuggestions.value = false;
            }
          },
        ),

        const SizedBox(height: 8),
        FutureBuilder<List<Location>>(
          future: results,
          builder: (context, snapshot) {
            if (!showSuggestions.value || searchQuery.value.isEmpty) {
              return const SizedBox.shrink();
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasData) {
              final locations = snapshot.data!;
              return ListView.builder(
                itemCount: locations.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  return ListTile(
                    title: Text(loc.name),
                    onTap: () {
                      controller.text = loc.name;
                      onLocationSelected(loc);
                      showSuggestions.value = false;
                    },
                  );
                },
              );
            } else {
              return const Text('No results');
            }
          },
        ),
      ],
    );
  }
}
