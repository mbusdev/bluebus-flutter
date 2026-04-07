import 'package:bluebus/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class LocationSearchBar extends HookWidget {
  final void Function(Location, bool, String) onLocationSelected;
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

    final refreshKey = useState(0);

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
              (abbrev != null) ? abbrev : "",
              [if (abbrev != null) abbrev, if (altName != null) altName],
              false,
              latlng: LatLng(lat, long),
            );
          }).toList();
        }

        // TODO: this code is DUPLICATED. We need to refactor to avoid duplication.
        // LOADS BOTH STOP TYPES
        final uriStops = Uri.parse(BACKEND_URL + '/getAllStops');
        final uriRideStops = Uri.parse(BACKEND_URL + '/getAllRideStops');

        // Calling in parallel
        final responses = await Future.wait([
          http.get(uriStops),
          http.get(uriRideStops),
        ]);

        // Helper function to parse a response into a List<Location>
        // This prevents copying/pasting the parsing logic.
        List<Location> parseLocations(http.Response response) {
          if (response.statusCode == 200 &&
              response.body.trim().isNotEmpty &&
              response.body.trim() != '{}') {
            
            final stopList = jsonDecode(response.body) as List<dynamic>;
            
            return stopList.map((stop) {
              final name = normalizeStopName(stop['name'] as String);
              final aliases = [
                name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join(),
              ];
              final stopId = stop['stpid'] as String?;
              final lat = stop['lat'] as double?;
              final lon = stop['lon'] as double?;
              
              return Location(
                name,
                (stopId != null) ? stopId : "",
                aliases,
                true,
                stopId: stopId,
                latlng: (lat != null && lon != null) ? LatLng(lat, lon) : null,
              );
            }).toList();
          }
          return []; // Return empty list if call failed or body is empty
        }

        // parse both and merge
        List<Location> stopLocs = [
          ...parseLocations(responses[0]),
          ...parseLocations(responses[1]),
        ];

        globalStopLocs = stopLocs;

        final allLocs = [...buildingLocs, ...stopLocs];
        if (allLocs.isEmpty) {
          refreshKey.value++;
        }

        return allLocs;
      } catch (e) {
        print('Failed to fetch locations: $e');
        refreshKey.value++;
        return <Location>[];
      }
    }, [refreshKey.value]);

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(56),
            ),
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.go,
              style:  TextStyle(
                color: getColor(context, ColorType.opposite).withAlpha(204),
                fontSize: 22
              ),
              autofocus: true,
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
                    selected.isBusStop,
                    selected.stopId ?? "",
                  );
                  showSuggestions.value = false;
                }
              },
            ),
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
              return Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: getColor(context, ColorType.opposite),
                      strokeWidth: 4,
                    ),
                  ),
                ),
              );
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
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: (loc.abbrev != "")
                        ? (loc.isBusStop)
                              ? Row(
                                  children: [
                                    Text("Stop ID: "),
                                    Text(
                                      loc.abbrev,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Text("Code: "),
                                    Text(
                                      loc.abbrev,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                        : (loc.isBusStop)
                        ? Text("Bus Stop")
                        : Text("University Building"),
                    leading: loc.isBusStop
                        ? Icon(
                            Icons.hail,
                            size: 40,
                            color: isDarkMode(context) ? Color.fromARGB(150, 255, 255, 255) : Color.fromARGB(150, 0, 0, 0),
                          )
                        : Icon(
                            Icons.business_rounded,
                            size: 40,
                            color: isDarkMode(context) ? Color.fromARGB(150, 255, 255, 255) : Color.fromARGB(150, 0, 0, 0),
                          ),
                    onTap: () {
                      controller.text = loc.name;
                      onLocationSelected(loc, loc.isBusStop, loc.stopId ?? "");
                      showSuggestions.value = false;
                    },
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(height: 0);
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
  final void Function(Location, bool, String) onSearch;

  const SearchSheet({super.key, required this.onSearch});

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
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [SheetBoxShadow]
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
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),

                SizedBox(width: 10),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
            child: LocationSearchBar(
              onLocationSelected: (location, isBusStop, stopID) {
                Navigator.pop(context);
                widget.onSearch(location, isBusStop, stopID);
              },
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                fillColor: getColor(context, ColorType.inputBackground),
                filled: true,
                hintText: 'where to?',
                hintStyle: TextStyle(
                  color: getColor(context, ColorType.inputText).withAlpha(204),
                  fontSize: 22,
                ),
                isCollapsed: true,
                prefixIcon: Padding(
                  padding: EdgeInsetsGeometry.only(left: 15),
                  child: Icon(
                    Icons.search,
                    size: 35,
                    color: getColor(context, ColorType.inputText),
                  ),
                ),
                
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(56.0)),
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(56.0)),
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
