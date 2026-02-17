import 'package:bluebus/theride_api.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/mini_stop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bluebus_api.dart';
import '../constants.dart';
import 'package:intl/intl.dart';

String futureTime(String minutesInFuture) {
  int min = int.parse(minutesInFuture);
  DateTime now = DateTime.now();
  DateTime futureTime = now.add(Duration(minutes: min));
  return DateFormat('hh:mm a').format(futureTime);
}

// Favorites sheet: reads a list of favorite stop ids from SharedPreferences
// under key 'favorite_stops' (List<String> of stop ids). For each favorite
// stop, it will fetch next arrivals and display a bullet-pointed list of the
// next few upcoming buses (up to 3) and allow removing the favorite.
class FavoritesSheet extends StatefulWidget {
  final void Function(String name, String id) onSelectStop;
  // optional callback invoked when a stop is unfavorited from this sheet
  final void Function(String stpid)? onUnfavorite;

  const FavoritesSheet({
    super.key,
    required this.onSelectStop,
    this.onUnfavorite,
  });

  @override
  State<FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<FavoritesSheet> {
  late Future<List<String>> _favoritesFuture;
  final Map<String, String> _stopIdToName = {};

  @override
  void initState() {

    // TODO: right now, every time the sheet opens it first fetches all the names from the backend
    // there should be a better way to cache this so we don't have to fetch every time
    // also this leads to weird "pop in" behavior
    super.initState();
    _favoritesFuture = _loadFavoriteStopIds();

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

  Future<List<String>> _loadFavoriteStopIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favorite_stops') ?? [];
  }

  Future<void> _removeFavorite(String stpid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_stops') ?? [];
    list.remove(stpid);
    await prefs.setStringList('favorite_stops', list);
    setState(() {
      _favoritesFuture = Future.value(list);
    });
    // notify parent (map) so it can update marker icons immediately
    try {
      widget.onUnfavorite?.call(stpid);
    } catch (_) {}
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
        FutureBuilder<List<String>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            double initChildSize = 0.9;
            if (snapshot.hasData && snapshot.data!.length == 0) {
              initChildSize = 0.3;
            }

            return DraggableScrollableSheet(
              initialChildSize: initChildSize,
              minChildSize: 0.0, // leave at 0.0 to allow full dismissal
              maxChildSize: 0.9,
              snap: true,
              snapSizes: const [0.9],
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: getColor(context, ColorType.background),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [SheetBoxShadow]
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Favorites',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (snapshot.connectionState == ConnectionState.waiting){
                              return const Center(child: CircularProgressIndicator());
                            } else if ((snapshot.data ?? []).isEmpty){
                              // code that creates the dialog box

                              // schedule for end of frame (to avoid crash)
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;

                                Navigator.of(context).pop();

                                showMaizebusOKDialog(
                                  contextIn: context,
                                  title: const Text("No Favorites"),
                                  content: const Text("Hit the heart icon on a stop to add it to your favorites and see it here!"),
                                );
                              });

                              return const SizedBox.shrink();
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  controller: scrollController,
                                  itemBuilder: (context, index) {
                                    final stpid = snapshot.data![index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: MiniStopSheet(
                                        stopID: stpid,
                                        stopName: _stopIdToName[stpid] ?? stpid,
                                        onUnfavorite: () {
                                          _removeFavorite(stpid);
                                        },
                                        onTapOnThis: () {
                                          Navigator.of(context).pop();
                                          widget.onSelectStop(
                                            _stopIdToName[stpid] ?? stpid,
                                            stpid,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          }
                        ) 
                      ),
                    ],
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
