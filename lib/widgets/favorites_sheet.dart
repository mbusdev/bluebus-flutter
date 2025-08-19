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
    return Text(stpid);
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
