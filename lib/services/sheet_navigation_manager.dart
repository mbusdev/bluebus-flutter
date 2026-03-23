import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/journey.dart';
import 'package:bluebus/providers/bus_provider.dart';
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:bluebus/widgets/bus_sheet.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/directions_sheet.dart';
import 'package:bluebus/widgets/favorites_sheet.dart';
import 'package:bluebus/widgets/journey_results_widget.dart';
import 'package:bluebus/widgets/route_selector_modal.dart';
import 'package:bluebus/widgets/search_sheet_main.dart';
import 'package:bluebus/widgets/stop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class SheetNavigationManager {
  PersistentBottomSheetController? _bottomSheetController;

  BuildContext context;
  Future<void> Function(String stpid, String name) addFavoriteStop;
  Function(
    Location location,
    bool startChanged,
    Map<String, double>? start,
    Map<String, double>? end,
    String startLoc,
    String endLoc,
    bool dontUseLocation
  ) onDirectionsChangeSelection;
  Function(Journey) onSelectJourney;
  Function(Map<String, double>, Map<String, double> dest) onDirectionsResolved;
  Function(Set<String>) onRouteSelectorApply;
  Function(Location location, bool isBusStop, String stopID) onSearch;
  Function(String name, String id) onSelectStop;
  Function(String stpid) onUnfavorite;
  Future<void> Function(String stpid, String name) removeFavoriteStop;

  SheetNavigationManager({
    required this.context,
    required this.addFavoriteStop,
    required this.onDirectionsChangeSelection,
    required this.onSelectJourney,
    required this.onDirectionsResolved,
    required this.onRouteSelectorApply,
    required this.onSearch,
    required this.onSelectStop,
    required this.onUnfavorite,
    required this.removeFavoriteStop
  });

  bool isBottomSheetControllerAlive() {
    return _bottomSheetController != null;
  }

  void resetBottomSheetController() {
    _bottomSheetController!.close();
    _bottomSheetController = null;
  }

  void showBuildingSheet(Location place) {
    // Show red pin at the location
    // _showSearchLocationMarker(place.latlng!.latitude, place.latlng!.longitude);

    _bottomSheetController = showBottomSheet(
      context: context,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BuildingSheet(
          building: place,
          onGetDirections: (Location location) {
            Map<String, double>? start;
            Map<String, double>? end = {
              'lat': place.latlng!.latitude,
              'lon': place.latlng!.longitude,
            };

            showDirectionsSheet(
              start,
              end,
              "Current Location",
              place.name,
              false
            );
          },
        );
      },
    );
  }

  void showDirectionsSheet(
    Map<String, double>? start,
    Map<String, double>? end,
    String startLoc,
    String endLoc,
    bool dontUseLocation,
  ) {
    _bottomSheetController = showBottomSheet(
      context: context,
      enableDrag: true,

      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0,
          expand: false,
          snap: true,
          snapSizes: [0.5, 0.9],
          builder: (context, scrollController) {
            return DirectionsSheet(
              origin: start,
              dest: end,
              useOrigin: dontUseLocation,
              originName: startLoc,
              destName: endLoc, // true = start changed, false = end changed
              onChangeSelection: (Location location, bool startChanged) {
                onDirectionsChangeSelection(
                  location,
                  startChanged,
                  start,
                  end,
                  startLoc,
                  endLoc,
                  dontUseLocation
                );
              },
              onSelectJourney: onSelectJourney,
              onResolved: onDirectionsResolved,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void showJourneySheetOnReopen(Journey currDisplayed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0,
          maxChildSize: 0.9,
          snap: true,
          expand: false,

          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: getColor(context, ColorType.background),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  Text(
                    'Steps',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 15),
                  JourneyBody(journey: currDisplayed),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showBusRoutesModal(
    List<BusRouteLine> allRouteLines,
    List<Map<String, String>> availableRoutes,
    Set<String> selectedRoutes,
    bool canVibrate
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return RouteSelectorModal(
          availableRoutes: availableRoutes,
          initialSelectedRoutes: selectedRoutes,
          onApply: onRouteSelectorApply,
          canVibrate: canVibrate,
        );
      },
    );
  }

  void showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SearchSheet(
          onSearch: onSearch,
        );
      },
    );
  }

  void showBusSheet(String busID) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.85,
          snap: true,

          builder: (BuildContext context, ScrollController scrollController) {
            return BusSheet(
              busID: busID,
              scrollController: scrollController,
              onSelectStop: (name, id) {
                Navigator.pop(context); // Close the current modal
                LatLng? latLong = getLatLongFromStopID(id);
                if (latLong != null) {
                  showStopSheet(id, name, latLong.latitude, latLong.longitude);
                } else {
                  showMaizebusOKDialog(
                    contextIn: context,
                    title: const Text("Error"),
                    content: const Text("Couldn't load stop."),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void showFavoritesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FavoritesSheet(
          onSelectStop: onSelectStop,
          onUnfavorite: onUnfavorite,
        );
      },
    );
  }

  void showStopSheet(
    String stopID,
    String stopName,
    double lat,
    double long,
  ) {
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StopSheet(
          stopID: stopID,
          stopName: stopName,
          onFavorite: addFavoriteStop,
          onUnFavorite: removeFavoriteStop,
          showBusSheet: (busId) {
            // When someone clicks "See all stops for this bus" this callback runs
            debugPrint("Got 'See all stops' click for Bus ${busId}");
            Navigator.pop(context); // Close the current modal
            showBusSheet(busId);
          },
          busProvider: busProvider,
          onGetDirections: () {
            Map<String, double>? start;
            Map<String, double>? end = {'lat': lat, 'lon': long};

            showDirectionsSheet(
              start,
              end,
              "Current Location",
              stopName,
              false,
            );
          },
        );
      },
    ).then((_) {});
  }

}