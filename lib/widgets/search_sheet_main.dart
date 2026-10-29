import 'package:bluebus/globals.dart';
import 'package:bluebus/providers/bathroom_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../services/location_search.dart';
import '../services/floorplan_service.dart';
import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/widgets/dialog.dart';
// import 'package:http/http.dart' as http;

Future<void> saveRecentSearch(Location loc) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('recentSearches');

  final recent = saved == null
      ? <Map<String, dynamic>>[]
      : (jsonDecode(saved) as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  // remove loc if it is already in recents, and insert it in the start
  recent.removeWhere((item) => item['name'] == loc.name);
  recent.insert(0, loc.toJson());

  // save the top recent searches
  await prefs.setString(
    'recentSearches',
    jsonEncode(recent.take(STORED_RECENT_SEARCHES).toList()),
  );
}

Future<List<Location>> getRecentSearches() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('recentSearches');
  if (saved == null) return [];

  final List<dynamic> entries;
  try {
    final decoded = jsonDecode(saved);
    if (decoded is! List) return [];
    entries = decoded;
  } on FormatException {
    return [];
  }

  final recent = <Location>[];
  for (final entry in entries) {
    if (entry is! Map<String, dynamic>) continue;
    try {
      // Each saved entry contains everything needed to recreate its location.
      switch (entry['kind']) {
        case 'room':
          recent.add(RoomLocation.fromJson(entry));
        case 'building': case 'stop':
          recent.add(Location.fromJson(entry));
      }
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
    if (recent.length == STORED_RECENT_SEARCHES) break;
  }
  return recent;
}

class Card {
  final String name;
  final ColorType color;
  final String type;
  const Card({required this.name, required this.color, required this.type});
}

// reusable widget that for search result tiles
class LocationTile extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;

  const LocationTile({
    super.key,
    required this.location,
    required this.onTap,
  });

  static getResultsListView(List<Location> locs) {

  }

  @override
  Widget build(BuildContext context) {
    final loc = location;

    final Widget subtitle;
    if (loc is RoomLocation) {
      subtitle = Text("${loc.room.building} - ${loc.room.floor.name}");
    } else if (loc.abbrev.isNotEmpty) {
      subtitle = Text.rich(
        TextSpan(
          text: loc.isBusStop ? "Stop ID: " : "Code: ",
          children: [
            TextSpan(
              text: loc.abbrev,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      subtitle = Text(loc.isBusStop ? "Bus Stop" : "University Building");
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      title: Text(
        loc is RoomLocation ? "Room ${loc.name}" : loc.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: subtitle,
      leading: Icon(
        loc.isBusStop ? Icons.hail : Icons.business_rounded, // add more icons when we have more floorplan data
        size: 40,
        color: getColor(context, ColorType.opposite),
      ),
      onTap: onTap,
    );
  }
}

class LocationSearchBar extends HookWidget {
  final void Function(Location, bool, String) onLocationSelected;
  final void Function(String)? onPOISelected;
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final List<LocatedFloorplanPoi> roomPois;

  const LocationSearchBar({
    super.key,
    required this.onLocationSelected,
    required this.onPOISelected,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    this.roomPois = const [],
  });

  // selectable cards
  static const List<Card> cards = [
    Card(name: "Bathroom", color: ColorType.roomSearchBathroom, type: FloorplanTypes.neutralBathroom),
    Card(name: "Info desk", color: ColorType.roomSearchInfoDesk, type: FloorplanTypes.information),
    Card(name: "Dining", color: ColorType.roomSearchDining, type: FloorplanTypes.food),
    Card(name: "Printing", color: ColorType.roomSearchPrinting, type: FloorplanTypes.printer),
    Card(name: "Stairs", color: ColorType.roomSearchStairs, type: FloorplanTypes.stairway),
    Card(name: "Vending", color: ColorType.roomSearchVending, type: FloorplanTypes.vendingMachine),
  ];

  // display names for POIs for the POI popup sheet after selecting a card
  static const Map<String, String> poiNames = {
    FloorplanTypes.femaleBathroom: "Women's Bathroom",
    FloorplanTypes.maleBathroom: "Men's Bathroom",
    FloorplanTypes.neutralBathroom: "Inclusive Bathroom",
    FloorplanTypes.information: "Info Desk",
    FloorplanTypes.food: "Dining",
    FloorplanTypes.vendingMachine: "Vending Machine",
    FloorplanTypes.printer: "Printer",
    FloorplanTypes.stairway: "Stairs",
  };

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

        final allLocs = [...buildingLocs, ...globalStopLocs];
        if (allLocs.isEmpty) {
          refreshKey.value++;
        }

        return allLocs;
      } catch (e) {
        print('Failed to fetch locations: $e');
        refreshKey.value++;
        return globalStopLocs;
      }
    }, [refreshKey.value]);

    // buildings and stops ngram index
    final ngramIndex = useMemoized(() async {
      final locs = await locations;
      return buildNgramIndex(locs);
    }, [locations]);

    final query = searchQuery.value;
    final results = useMemoized(() async {
      final idx = await ngramIndex;
      return searchLocations(query, idx, roomPois);
    }, [query, ngramIndex, roomPois]);

    // recent search results
    final recentSearchesFuture = useMemoized(() => getRecentSearches(), []);
    final recentSearches = useFuture(recentSearchesFuture);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 16),
          child: SizedBox(
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
                  final matches = searchLocations(val, idx, roomPois);
                  if (!context.mounted) return;

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
        ),

        const SizedBox(height: 20),
        
        // Cards
        if (onPOISelected != null)
          SizedBox(
            height: 31,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  height: 31,
                  child: FilledButton(
                    onPressed: () async {
                      // poi button pressed
                      String type = cards[index].type;

                      // if bathrooom selected
                      if (cards[index].color == ColorType.roomSearchBathroom) {
                        BathroomProvider bathroom = Provider.of<BathroomProvider>(context, listen: false);
                        
                        // show dialog if not chosen yet
                        if (bathroom.preference == BathroomPreference.notchosen) {
                          String? result = await showDialogOptions(
                            contextIn: context,
                            title: "Bathroom Preference",
                            content: "Which bathroom do you prefer? You can change this later.",
                            options: ["Women's", "Men's", "Inclusive"]
                          );

                          if (result == null) return;
                          if (!context.mounted) return;

                          // set bathroom save data to the user results button
                          bathroom.set(switch (result) {
                            "Women's" => BathroomPreference.womens,
                            "Men's" => BathroomPreference.mens,
                            _ => BathroomPreference.inclusive,
                          });
                        }

                        // set type chosen based on the preference
                        type = switch(bathroom.preference) {
                          BathroomPreference.womens => FloorplanTypes.femaleBathroom,
                          BathroomPreference.mens => FloorplanTypes.maleBathroom,
                          _ => FloorplanTypes.neutralBathroom
                        };
                      }

                      onPOISelected!(type);
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          100.0,
                        ), // Adjust the pixels for rounding
                      ),
                      backgroundColor: getColor(context, cards[index].color),
                      padding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(
                      cards[index].name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
              // This builds the gap between each item
              separatorBuilder: (context, index) {
                return const SizedBox(
                  width: 5,
                ); // Adjust height for vertical lists, width for horizontal
              },
            ),
          ),

        if (onPOISelected != null)
          const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 16),
          child: FutureBuilder<List<Location>>(
            future: results,
            builder: (context, snapshot) {
              if (!showSuggestions.value || searchQuery.value.isEmpty) {
                if (recentSearches.data?.isEmpty ?? true) {
                  return SizedBox.shrink();
                }

                final recents = recentSearches.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    Text(
                      "Recent Searches",
                      style: TextStyle(
                        color: getColor(context, ColorType.roomSearchText),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // this is duplicated code from normal search results, below
                    // could put this in a function or widget or something?
                    ListView.separated(
                      itemCount: recents.length,
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final loc = recents[index];
                        return LocationTile(
                          location: loc,
                          onTap: () {
                            controller.text = loc.name;
                            onLocationSelected(loc, loc.isBusStop, loc.stopId ?? "");
                            showSuggestions.value = false;
                            saveRecentSearch(loc);
                          }
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(height: 20);
                      },
                    ),
                  ],
                );
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
                    return LocationTile(
                      location: loc,
                      onTap: () {
                        controller.text = loc.name;
                        onLocationSelected(loc, loc.isBusStop, loc.stopId ?? "");
                        showSuggestions.value = false;
                        saveRecentSearch(loc);
                      }
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Divider(height: 20);
                  },
                );
              } else {
                return const Text('No results');
              }
            },
          ),
        ),
      ],
    );
  }
}

// Selecting routes
class SearchSheet extends StatefulWidget {
  final bool isRoomSearch; // changes hint text displayed: "where to?" vs "Room #"
  final void Function(Location, bool, String) onSearch;
  final void Function(String)? onPOISelected;
  final List<LocatedFloorplanPoi> roomPois; // Empty when room data is unavailable.

  const SearchSheet({super.key, required this.isRoomSearch, required this.onSearch, this.onPOISelected, this.roomPois = const []});

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

          const SizedBox(height: 10),

          LocationSearchBar(
            onLocationSelected: (location, isBusStop, stopID) {
              Navigator.pop(context);
              widget.onSearch(location, isBusStop, stopID);
            },
            onPOISelected: widget.onPOISelected == null ? null : (name) {
              Navigator.pop(context);
              widget.onPOISelected!(name);
            },
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              fillColor: getColor(context, ColorType.inputBackground),
              filled: true,
              hintText: widget.isRoomSearch ? "Room #" : "where to?",
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
            roomPois: widget.roomPois,
          ),
        ]
      )
    );
  }
}
