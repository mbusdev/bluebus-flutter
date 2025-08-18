import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bluebus_api.dart';
import '../constants.dart';

// Favorites sheet: reads a list of favorite stop ids from SharedPreferences
// under key 'favorite_stops' (List<String> of stop ids). For each favorite
// stop, it will fetch next arrivals and display a bullet-pointed list of the
// next few upcoming buses (up to 3) and allow removing the favorite.
class FavoritesSheet extends StatefulWidget {
  const FavoritesSheet({super.key});

  @override
  State<FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<FavoritesSheet> {
  late Future<List<String>> _favoritesFuture;
  final Map<String, String> _stopIdToName = {};

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavoriteStopIds();

    // Build stop id -> name map to show readable names in the list.
    BlueBusApi.fetchRoutes()
        .then((routes) {
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
  }

  Widget _buildStopTile(String stpid) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: BlueBusApi.fetchArrivalsForStop(stpid),
      builder: (context, snapshot) {
        final title = _stopIdToName[stpid] ?? stpid;

        Widget subtitleChild;

        if (snapshot.connectionState == ConnectionState.waiting) {
          subtitleChild = const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (snapshot.hasError) {
          subtitleChild = Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Could not load upcoming buses.')),
                TextButton(
                  onPressed: () => setState(() {}), // retry by rebuilding
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          subtitleChild = const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('No upcoming buses'),
          );
        } else {
          final arrivals = snapshot.data!;
          final items = arrivals.take(3).map((a) {
            final rt = a['rt'] ?? a['route'] ?? '';
            final at = a['arrivalTime'] ?? a['eta'] ?? a['time'];
            String inMinutes;
            try {
              final now = DateTime.now();
              DateTime arrTime;
              if (at is int) {
                // seconds vs milliseconds heuristic
                if (at < 10000000000) {
                  arrTime = DateTime.fromMillisecondsSinceEpoch(at * 1000);
                } else {
                  arrTime = DateTime.fromMillisecondsSinceEpoch(at);
                }
              } else if (at is String) {
                final parsed = int.tryParse(at) ?? 0;
                if (parsed < 10000000000) {
                  arrTime = DateTime.fromMillisecondsSinceEpoch(parsed * 1000);
                } else {
                  arrTime = DateTime.fromMillisecondsSinceEpoch(parsed);
                }
              } else {
                arrTime = now;
              }
              final diff = arrTime.difference(now);
              final mins = diff.inMinutes;
              inMinutes = mins <= 0 ? 'due' : '${mins}m';
            } catch (_) {
              inMinutes = '?';
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text('•', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: Text(
                      '${getPrettyRouteName(rt)} — $inMinutes',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList();

          subtitleChild = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items,
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: subtitleChild,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeFavorite(stpid),
          ),
          onTap: () => Navigator.of(context).pop(),
        );
      },
    );
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
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Favorites',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<String>>(
              future: _favoritesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final favs = snapshot.data ?? [];
                if (favs.isEmpty) {
                  return const Center(child: Text('No favorites yet'));
                }

                return ListView.separated(
                  itemCount: favs.length,
                  separatorBuilder: (context, idx) => const Divider(height: 0),
                  itemBuilder: (context, idx) {
                    final stpid = favs[idx];
                    return _buildStopTile(stpid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
