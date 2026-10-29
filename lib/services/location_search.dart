import '../constants.dart';
import '../models/floorplan.dart';
import 'floorplan_service.dart';

class RoomLocation extends Location {
  final LocatedFloorplanPoi room;

  RoomLocation(this.room)
    : super(room.poi.name ?? '', '', const [], false, latlng: room.position);
}

// Searches the whole user query in the building/stop search,
// then also checks words at either end (split by spaces) for room numbers,
// ranking room numbers of current building query above others.
// The return list has a RoomLocation instead of a Location for room results 
List<Location> searchLocations(
  String query,
  Map<String, Set<Location>> index,
  List<LocatedFloorplanPoi> rooms,
) {
  // Normalize once before building and room searches.
  final words = query.trim().toLowerCase().split(RegExp(r'\s+'));
  var locations = _ngramSearch(words.join(' '), index); // original building search
  final roomRanks = <LocatedFloorplanPoi, int>{};

  // Both ends can be numeric ("building 12 210" or "210 building 12").
  // Keep each interpretation, and deduplicate rooms before displaying them.
  for (final edge in {words.length - 1, 0}) {
    // find edge words that contain more digits than letters, ignore those that are mostly letters
    final number = words[edge];
    final digits = RegExp(r'[0-9]').allMatches(number).length;
    final letters = RegExp(r'[a-z]').allMatches(number).length;
    if (digits <= letters) continue; 

    // perform an ngram building search of the query with the potential room number removed
    final buildingWords = [...words]..removeAt(edge); // make a copy and remove the room number word
    final buildingQuery = buildingWords.join(' ');
    final buildingsAndStops = _ngramSearch(
      buildingQuery, index,
    ); // ignore bus stops
    final buildings = buildingsAndStops.where((location) => !location.isBusStop).toList();

    // Floorplan names can be shorter than backend names (e.g. Duderstadt).
    // Resolve each building once per interpretation, using the same index.
    final buildingRanks = <String, int>{};
    for (final room in rooms) {
      // check that the room number starts with the search query number
      if (!(room.poi.name?.trim().toLowerCase().startsWith(number) ?? false)) {
        continue;
      }

      // buildingRanks caches the building ranks,
      // creating a map from room buildings to actual buildings' ranks
      final rank = buildingRanks.putIfAbsent(room.building, () {
        // finds the building that the room belongs to
        final candidates = _ngramSearch(
          room.building.trim().toLowerCase(), index,
        ).where((location) => !location.isBusStop);
        final building = candidates.firstOrNull;
        final position = building == null ? -1 : buildings.indexOf(building);
        // if room's building is not in the building results, place its rank at position 10,
        // after all the rooms that match within a building in the search results
        return position < 0 ? 10 : position; 
      });
      
      // set new search results building list, if whole-query results is empty and room results is not empty
      if (locations.isEmpty && rooms.isNotEmpty && buildingsAndStops.isNotEmpty) {
        locations = buildingsAndStops;
      }

      // checks for duplicate room showing up
      final previous = roomRanks[room];
      if (previous == null || rank < previous) roomRanks[room] = rank;
    }
  }

  // orders the rooms by rank, keeping the original order for ties,
  // and takes max 10 rooms, along with the rest of the building location results
  final matches = roomRanks.keys.toList();
  final order = {for (var i = 0; i < matches.length; i++) matches[i]: i};
  matches.sort((a, b) {
    final rank = roomRanks[a]!.compareTo(roomRanks[b]!);
    return rank != 0 ? rank : order[a]!.compareTo(order[b]!);
  });
  return [...matches.take(10).map(RoomLocation.new), ...locations];
}

// Shared character-chunk index for building names, aliases, and bus stops.
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

// Callers supply a trimmed, lowercase query.
List<Location> _ngramSearch(String query, Map<String, Set<Location>> index) {
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
