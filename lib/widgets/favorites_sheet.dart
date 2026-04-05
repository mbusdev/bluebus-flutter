import 'package:bluebus/theride_api.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/mini_stop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bluebus_api.dart';
import '../constants.dart';
import '../util/favorite_building_storage.dart';
import 'package:intl/intl.dart';

String futureTime(String minutesInFuture) {
  int min = int.parse(minutesInFuture);
  DateTime now = DateTime.now();
  DateTime futureTime = now.add(Duration(minutes: min));
  return DateFormat('hh:mm a').format(futureTime);
}

enum _FavoritesSegment { stops, buildings }

// Favorites sheet: favorite stops (arrivals) and favorite buildings (saved from building sheet).
class FavoritesSheet extends StatefulWidget {
  final void Function(String name, String id) onSelectStop;
  final void Function(Location location) onSelectBuilding;
  /// Same flow as [BuildingSheet] directions (current location → this building).
  final void Function(Location location) onBuildingGetDirections;
  // optional callback invoked when a stop is unfavorited from this sheet
  final void Function(String stpid)? onUnfavorite;

  const FavoritesSheet({
    super.key,
    required this.onSelectStop,
    required this.onSelectBuilding,
    required this.onBuildingGetDirections,
    this.onUnfavorite,
  });

  @override
  State<FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<FavoritesSheet> {
  late Future<({List<String> stops, List<FavoriteBuildingEntry> buildings})>
      _favoritesFuture;
  final Map<String, String> _stopIdToName = {};
  /// User-selected tab; when null, [_resolvedSegment] picks stops if any, else buildings.
  _FavoritesSegment? _segment;

  @override
  void initState() {

    // TODO: right now, every time the sheet opens it first fetches all the names from the backend
    // there should be a better way to cache this so we don't have to fetch every time
    // also this leads to weird "pop in" behavior
    super.initState();
    _favoritesFuture = _loadFavorites();

    // Build stop id -> name map to show readable names in the list.
    BlueBusApi.fetchRoutes()
        .then((routes) {
          if (!mounted) return; // makes sure widget hasn't been closed while waiting for this
          final map = <String, String>{};
          for (final r in routes) {
            for (final s in r.stops) {
              if (!map.containsKey(s.id)) map[s.id] = s.name;
            }
          }
          setState(() => _stopIdToName.addAll(map));
        })
        .catchError((_) {
          // ignore errors building names
        });

    // same for ride
    RideAPI.fetchRoutes()
        .then((routes) {
          if (!mounted) return; // makes sure widget hasn't been closed while waiting for this
          final map = <String, String>{};
          for (final r in routes) {
            for (final s in r.stops) {
              if (!map.containsKey(s.id)) map[s.id] = s.name;
            }
          }
          setState(() => _stopIdToName.addAll(map));
        })
        .catchError((_) {
          // ignore errors building names
        });

  }

  Future<({List<String> stops, List<FavoriteBuildingEntry> buildings})>
      _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stops = prefs.getStringList('favorite_stops') ?? [];
    final rawBuildings = prefs.getStringList(kFavoriteBuildingsPrefsKey) ?? [];
    final buildings = <FavoriteBuildingEntry>[];
    for (final s in rawBuildings) {
      final e = decodeFavoriteBuildingEntry(s);
      if (e != null) buildings.add(e);
    }
    return (stops: stops, buildings: buildings);
  }

  Future<void> _removeFavoriteStop(String stpid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_stops') ?? [];
    list.remove(stpid);
    await prefs.setStringList('favorite_stops', list);
    if (!mounted) return;
    setState(() {
      _favoritesFuture = _loadFavorites();
    });
    try {
      widget.onUnfavorite?.call(stpid);
    } catch (_) {}
  }

  Future<void> _removeFavoriteBuilding(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kFavoriteBuildingsPrefsKey) ?? [];
    list.remove(raw);
    await prefs.setStringList(kFavoriteBuildingsPrefsKey, list);
    if (!mounted) return;
    setState(() {
      _favoritesFuture = _loadFavorites();
    });
  }

  _FavoritesSegment _resolvedSegment(
    List<String> stops,
    List<FavoriteBuildingEntry> buildings,
  ) {
    return _segment ??
        (stops.isNotEmpty
            ? _FavoritesSegment.stops
            : _FavoritesSegment.buildings);
  }

  void _selectSegment(
    _FavoritesSegment next,
    ScrollController scrollController,
  ) {
    setState(() => _segment = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // stacking the sheet on top of a gesture detector so you can close it by tapping out of it
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(),
          ),
        ),
        FutureBuilder<({List<String> stops, List<FavoriteBuildingEntry> buildings})>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            double initChildSize = 0.9;
            final totalCount = snapshot.hasData
                ? snapshot.data!.stops.length + snapshot.data!.buildings.length
                : 0;
            if (snapshot.hasData && totalCount == 0) {
              initChildSize = 0.3;
            }

            return DraggableScrollableSheet(
              initialChildSize: initChildSize,
              minChildSize: 0.0, // leave at 0.0 to allow full dismissal
              maxChildSize: 0.9,
              snap: true,
              snapSizes: const [0.9],
              builder: (BuildContext context, ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: getColor(context, ColorType.background),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [SheetBoxShadow]
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Builder(
                            builder: (context) {
                              if (snapshot.connectionState == ConnectionState.waiting){
                                return const Center(child: CircularProgressIndicator());
                              } else if (totalCount == 0) {
                                // schedule for end of frame (to avoid crash)
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!context.mounted) return;

                                  Navigator.of(context).pop();

                                  showMaizebusOKDialog(
                                    contextIn: context,
                                    title: const Text("No Favorites"),
                                    content: const Text(
                                      "Hit the heart on a bus stop or building to add it here.",
                                    ),
                                  );
                                });

                                return const SizedBox.shrink();
                              } else {
                                final stops = snapshot.data!.stops;
                                final buildings = snapshot.data!.buildings;
                                final seg = _resolvedSegment(stops, buildings);
                                final itemCount = seg == _FavoritesSegment.stops
                                    ? (stops.isEmpty
                                        ? 2
                                        : 1 + stops.length)
                                    : (buildings.isEmpty
                                        ? 2
                                        : 1 + buildings.length);

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: itemCount,
                                        controller: scrollController,
                                        itemBuilder: (context, index) {
                                          if (index == 0) {
                                            return const SizedBox(
                                              height: 70,
                                            );
                                          }
                                          index -= 1;
                                          if (seg ==
                                              _FavoritesSegment.stops) {
                                            if (stops.isEmpty) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 32,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'No favorite stops',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'Urbanist',
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: getColor(
                                                        context,
                                                        ColorType.dim,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            final stpid = stops[index];
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                left: 20,
                                                right: 20,
                                                bottom: 10,
                                                top: 10,
                                              ),
                                              child: MiniStopSheet(
                                                stopID: stpid,
                                                stopName:
                                                    _stopIdToName[stpid] ??
                                                        stpid,
                                                onUnfavorite: () {
                                                  _removeFavoriteStop(stpid);
                                                },
                                                onTapOnThis: () {
                                                  Navigator.of(context).pop();
                                                  widget.onSelectStop(
                                                    _stopIdToName[stpid] ??
                                                        stpid,
                                                    stpid,
                                                  );
                                                },
                                              ),
                                            );
                                          }
                                          if (buildings.isEmpty) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 32,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'No favorite buildings',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: 'Urbanist',
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                    color: getColor(
                                                      context,
                                                      ColorType.dim,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          final b = buildings[index];
                                          final buildingLoc = b.toLocation();
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              left: 20,
                                              right: 20,
                                              bottom: 10,
                                              top: 10,
                                            ),
                                            child: _MiniFavoriteBuildingCard(
                                              entry: b,
                                              onUnfavorite: () {
                                                _removeFavoriteBuilding(b.raw);
                                              },
                                              onTap: () {
                                                Navigator.of(context).pop();
                                                if (buildingLoc != null) {
                                                  widget.onSelectBuilding(
                                                    buildingLoc,
                                                  );
                                                }
                                              },
                                              onDirections: buildingLoc ==
                                                      null
                                                  ? null
                                                  : () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      widget
                                                          .onBuildingGetDirections(
                                                        buildingLoc,
                                                      );
                                                    },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SafeArea(
                                      top: false,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          4,
                                          16,
                                          12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _FavoritesSegmentButton(
                                                label:
                                                    'Stops (${stops.length})',
                                                selected: seg ==
                                                    _FavoritesSegment.stops,
                                                selectedBackground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .importantButtonBackground,
                                                ),
                                                selectedForeground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .importantButtonText,
                                                ),
                                                unselectedBackground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .secondaryButtonBackground,
                                                ),
                                                unselectedForeground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .secondaryButtonText,
                                                ),
                                                onTap: () => _selectSegment(
                                                  _FavoritesSegment.stops,
                                                  scrollController,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _FavoritesSegmentButton(
                                                label:
                                                    'Buildings (${buildings.length})',
                                                selected: seg ==
                                                    _FavoritesSegment
                                                        .buildings,
                                                selectedBackground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .importantButtonBackground,
                                                ),
                                                selectedForeground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .importantButtonText,
                                                ),
                                                unselectedBackground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .secondaryButtonBackground,
                                                ),
                                                unselectedForeground:
                                                    getColor(
                                                  context,
                                                  ColorType
                                                      .secondaryButtonText,
                                                ),
                                                onTap: () => _selectSegment(
                                                  _FavoritesSegment.buildings,
                                                  scrollController,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }
                          ) 
                        ),
                  
                        // gradient box for title background
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 75,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  getColor(context, ColorType.background),       
                                  getColor(context, ColorType.backgroundGradientStart),  
                                ],
                                stops: [0.85, 1]
                              ),
                            ),
                          ),
                        ),
                    
                        // title
                        const Padding(
                          padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Favorites',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _FavoritesSegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color unselectedBackground;
  final Color unselectedForeground;
  final VoidCallback onTap;

  const _FavoritesSegmentButton({
    required this.label,
    required this.selected,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.unselectedBackground,
    required this.unselectedForeground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedBackground : unselectedBackground;
    final fg = selected ? selectedForeground : unselectedForeground;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact building row for the favorites list (mirrors [MiniStopSheet] chrome).
class _MiniFavoriteBuildingCard extends StatelessWidget {
  final FavoriteBuildingEntry entry;
  final VoidCallback onUnfavorite;
  final VoidCallback onTap;
  /// When non-null, shows a Directions control like [BuildingSheet].
  final VoidCallback? onDirections;

  const _MiniFavoriteBuildingCard({
    required this.entry,
    required this.onUnfavorite,
    required this.onTap,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getColor(context, ColorType.infoCardColor),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [getInfoCardShadow(context)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.apartment,
                      color: getColor(context, ColorType.secondaryButtonText),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: const TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          height: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onUnfavorite,
                      child: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                if (entry.toLocation() == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'No map location saved for this entry.',
                    style: TextStyle(
                      fontFamily: 'Urbanist',
                      fontSize: 14,
                      color: getColor(context, ColorType.dim),
                    ),
                  ),
                ],
                if (onDirections != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onDirections,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getColor(
                          context,
                          ColorType.importantButtonBackground,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                      ),
                      icon: Icon(
                        Icons.directions,
                        color: getColor(context, ColorType.importantButtonText),
                        size: 18,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Directions',
                          maxLines: 1,
                          style: TextStyle(
                            color: getColor(
                              context,
                              ColorType.importantButtonText,
                            ),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
