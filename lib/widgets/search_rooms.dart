import 'package:bluebus/models/floorplan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';
// import 'package:http/http.dart' as http;

class Card {
  final String name;
  final ColorType color;
  const Card({required this.name, required this.color});
}

class RoomSearchBar extends HookWidget {
  final void Function(FloorplanFloor, FloorplanPoi) onLocationSelected;
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final List<FloorplanFloor> floors;

  // selectable cards
  static const List<Card> cards = [
    Card(name: "Bathroom", color: ColorType.roomSearchBathroom),
    Card(name: "Info desk", color: ColorType.roomSearchInfoDesk),
    Card(name: "Dining", color: ColorType.roomSearchDining),
    Card(name: "Printing", color: ColorType.roomSearchPrinting),
    Card(name: "Stairs", color: ColorType.roomSearchStairs),
  ];

  const RoomSearchBar({
    super.key,
    required this.onLocationSelected,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.floors,
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

    // simple search for now
    // TODO: needs to be sorted by order of closest distance still
    // and also account for different buildings, which it does not do
    List<({FloorplanFloor floor, FloorplanPoi poi})> search(String query) {
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return [];

      final matches = <({FloorplanFloor floor, FloorplanPoi poi})>[];
      for (final floor in floors) {
        for (final poi in floor.pois) {
          if (poi.type == FloorplanTypes.waypoint1 ||
              poi.type == FloorplanTypes.waypoint2) {
            continue;
          }
          if ((poi.name ?? '').toLowerCase().contains(normalizedQuery)) {
            matches.add((floor: floor, poi: poi));
          }
        }
      }
      return matches;
    }

    // Memoize search results.
    final results = useMemoized(() async {
      return search(searchQuery.value);
    }, [searchQuery.value, floors]);

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
                style: TextStyle(
                  color: getColor(context, ColorType.opposite).withAlpha(204),
                  fontSize: 22,
                ),
                autofocus: true,
                controller: controller,
                focusNode: focusNode,
                decoration: decoration,
                onChanged: (val) {
                  searchQuery.value = val;
                  showSuggestions.value = true;
                },
                onSubmitted: (val) {
                  final matches = search(val);
                  if (matches.isNotEmpty) {
                    final selected = matches.first;
                    controller.text = selected.poi.name ?? selected.poi.type;
                    onLocationSelected(selected.floor, selected.poi);
                    showSuggestions.value = false;
                  }
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Cards
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
                  onPressed: () {},
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

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 16),
          child: FutureBuilder<List<({FloorplanFloor floor, FloorplanPoi poi})>>(
            future: results,
            builder: (context, snapshot) {
              if (!showSuggestions.value || searchQuery.value.isEmpty) {
                return Text(
                  "Recent Searches",
                  style: TextStyle(
                    color: getColor(context, ColorType.roomSearchText),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }

              // Loading circle
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
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              // Has data, return matching POIs.
              final matches = snapshot.data!;
              return ListView.separated(
                itemCount: matches.length,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final result = matches[index];
                  final poi = result.poi;
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 2, right: 2),
                    title: Text(
                      poi.name ?? poi.type,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Duderstadt Building ${result.floor.name}"
                    ),
                    leading: Icon(
                      Icons.business_rounded,
                      size: 40,
                      color: getColor(context, ColorType.opposite)
                    ),
                    onTap: () {
                      controller.text = poi.name ?? poi.type;
                      onLocationSelected(result.floor, poi);
                      showSuggestions.value = false;
                    },
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(height: 15);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Selecting routes
class SearchRoomsSheet extends StatefulWidget {
  final List<FloorplanFloor> floors;

  const SearchRoomsSheet({super.key, required this.floors});

  @override
  State<SearchRoomsSheet> createState() => _SearchRoomsSheetState();
}

class _SearchRoomsSheetState extends State<SearchRoomsSheet> {
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
        boxShadow: [SheetBoxShadow],
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

          RoomSearchBar(
            onLocationSelected: (floor, poi) {
              Navigator.pop(context, (floor: floor, poi: poi));
            },
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              fillColor: getColor(context, ColorType.roomSearchBg),
              filled: true,
              hintText: 'Room #',
              hintStyle: TextStyle(
                color: getColor(context, ColorType.roomSearchText),
                fontSize: 22,
              ),
              isCollapsed: true,
              prefixIcon: Padding(
                padding: EdgeInsetsGeometry.only(left: 15),
                child: Icon(
                  Icons.search,
                  size: 35,
                  color: getColor(context, ColorType.roomSearchText),
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
            floors: widget.floors,
          ),
        ],
      ),
    );
  }
}
