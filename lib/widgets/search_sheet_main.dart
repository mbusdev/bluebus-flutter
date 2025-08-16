import 'package:bluebus/globals.dart';
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
import '../globals.dart';

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
        final buildingResponse = await http.get(
          Uri.parse(BACKEND_URL + '/getBuildingLocations'),
        );
        List<Location> buildingLocs = [];
        if (buildingResponse.statusCode == 200 &&
            buildingResponse.body.trim().isNotEmpty &&
            buildingResponse.body.trim() != '{}') {
          final buildingLocations =
              jsonDecode(buildingResponse.body) as List<dynamic>;
          buildingLocs = buildingLocations.map((building) {
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
        }

        final stopResponse = await http.get(
          Uri.parse(BACKEND_URL + '/getAllStops'),
        );
        List<Location> stopLocs = [];
        if (stopResponse.statusCode == 200 &&
            stopResponse.body.trim().isNotEmpty &&
            stopResponse.body.trim() != '{}') {
          final stopList = jsonDecode(stopResponse.body) as List<dynamic>;
          stopLocs = stopList.map((stop) {
            final name = stop['name'] as String;
            final aliases = [name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join()];
            final stopId = stop['stpid'] as String?;
            final lat = stop['lat'] as double?;
            final lon = stop['lon'] as double?;
            return Location(
              name,
              (stopId != null)? stopId : "",
              aliases,
              true,
              stopId: stopId,
              latlng: (lat != null && lon != null) ? LatLng(lat, lon) : null,
            );
          }).toList();
        }

        globalStopLocs = stopLocs;

        return [...buildingLocs, ...stopLocs];
      } catch (e) {
        print('Failed to fetch locations: $e');
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
        SizedBox(
          height: 50,
          child: TextField(
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
              return ListView.separated(
                itemCount: locations.length,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 2, right: 2),
                    title: Text(
                      loc.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: (loc.abbrev != "")?
                      (loc.isBusStop)? 
                      Row(
                        children: [
                          Text("Stop ID: "),
                          Text(loc.abbrev, style: TextStyle(
                            fontWeight: FontWeight.bold,)
                          )
                        ]
                      )
                      : 
                      Row(
                        children: [
                          Text("Code: "),
                          Text(loc.abbrev, style: TextStyle(
                            fontWeight: FontWeight.bold,)
                          )
                        ],
                      ) : 
                      (loc.isBusStop)? Text("Bus Stop") : Text("University Building"),
                    leading: loc.isBusStop? Icon(Icons.hail, size: 40, color: Color.fromARGB(150, 0, 0, 0),)
                                          : Icon(Icons.business_rounded, size: 40, color: Color.fromARGB(150, 0, 0, 0),),
                    onTap: () {
                      controller.text = loc.name;
                      onLocationSelected(loc);
                      showSuggestions.value = false;
                    },
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const Divider(
                    height: 0,
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


// Selecting routes
class SearchSheet extends StatefulWidget {
  final void Function(Location selected) onSearch;

  const SearchSheet({
    Key? key,
    required this.onSearch,
  }) : super(key: key);

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

// State for the route selector
class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 20, bottom: 4), 
            child: Row(
              children: [
                const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),

                SizedBox(width: 10,),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 198, 191, 255),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),

                    const Text(
                      'BETA',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ]
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: LocationSearchBar(
              onLocationSelected: (location) {
                Navigator.pop(context); 
                widget.onSearch(location);
              },
              controller: _searchController, 
              focusNode: _searchFocusNode, 
              decoration: /*InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Start typing...',
                border: OutlineInputBorder(),
              ),*/
              InputDecoration(
                fillColor: Color.fromARGB(255, 235, 235, 235), // A light grey color
                filled: true,
                hintText: 'Start typing...',
                prefixIcon: Icon(Icons.search),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 0,
                  ),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  borderSide: BorderSide(
                    color: Colors.transparent,
                    width: 0,
                  ),
                ),
              )
            ),
          ),
        ],
      )
    );
  }
} 