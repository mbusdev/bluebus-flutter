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

enum ShadowType {
  noShadow,
  fadeInShadow,
  fullShadow
}

typedef PushSheet = void Function(Widget sheet);

// A custom context that allows the ScrollController to be assigned dynamically.
//
// For the transition, SheetNavigator stacks two sheets on top of each other
// (i.e. a StopSheet on top of a BusSheet) so you can see the bottom sheet while
// you were swiping away the top sheet.
//
// Problem was--because both sheets are dispayed at the same time, both had
// access to the DraggableScrollableSheet's ScrollController, and the background
// sheet would fight the foreground sheet when the user tried to swipe the
// modal down. Thus, SheetNavigationContext hangs on to the ScrollController
// and dishes it out (or not) as necessary to whatever sheets it contains to
// prevent conflicts.
class SheetNavigationContext extends InheritedWidget {
  final ScrollController scrollController;

  const SheetNavigationContext({required this.scrollController, required super.child});

  // The static accessor - this is the "of(context)" pattern
  static SheetNavigationContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SheetNavigationContext>();
  }

  @override
  bool updateShouldNotify(SheetNavigationContext old) => scrollController != old.scrollController;
}

class SheetNavigator extends StatefulWidget {
  final Function(ScrollController, PushSheet) initialSheetBuilder;
  final ScrollController scrollController;
  SheetNavigator({
    required this.scrollController,
    required this.initialSheetBuilder
  });
  
  @override
  State<StatefulWidget> createState() => SheetNavigatorState();
}

// SheetNavigator is a custom widget that allows multiple sheets to be displayed, one after another.
// Useful if the user is navigating through many Sheets (e.g. BusSheet to StopSheet to BusSheet)
// SheetNavigator manages its back stack, so the Android back button (and whatever back buttons
// you add to the UI) go backwards through history with a nice card animation
class SheetNavigatorState extends State<SheetNavigator> {
  List<Widget> _stack = [];
  bool isGoingBackwards = false;
  int numSteps = 0; // Used for the Dismissable key
  bool shouldAnimate = true; // Used to prevent a "double animation" happening after the user swipes away a sheet
  final ScrollController inactiveScrollController = ScrollController(); // Given to the sheet in the background so it doesn't fight when closing the modal

  void pushWidget(Widget sheet) {
    setState(() {
      shouldAnimate = true;
      _stack.add(sheet);
      isGoingBackwards = false;
      numSteps++;
    });
  }

  void popWidget() {
    setState(() {
      _stack.removeLast();
      isGoingBackwards = true;
      numSteps++;
    });
  }

  void popWidgetNoAnimation() {    
    setState(() {
      shouldAnimate = false;
      _stack.removeLast();
      isGoingBackwards = true;
      numSteps++;
    });

  }

  @override
  void initState() {
    super.initState();
    _stack.add(widget.initialSheetBuilder(widget.scrollController, pushWidget));
  }

  @override
  void dispose() {
    inactiveScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    

    return PopScope(
      canPop: _stack.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        // When the Android back button is pressed (or the current widget gets closed programatically),
        // it's routed here and SheetNavigator takes the current sheet off the back stack 
        if (!didPop) {
          shouldAnimate = true; // User clicked back button so we need a back animation
          popWidget();
        }
        
      }, child: Container(
        decoration: BoxDecoration(
          boxShadow: [SheetBoxShadow] // Shadow that sits behind all the sheets in the SheetNavigator
        ),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isEntering = child.key == ValueKey(_stack.length);
            
            return SlideTransition(
              // All this positioning logic serves to make the forward and backward card animations look nice
              position: Tween<Offset>(
                begin: 
                !shouldAnimate ? (
                  Offset.zero
                )
                : isGoingBackwards ? (
                    isEntering ?
                      const Offset(-1, 0.0) : const Offset(1, 0.0)
                  ) : isEntering ?
                    const Offset(1, 0.0)
                    : const Offset(0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: (isGoingBackwards && !isEntering) ? Curves.easeInOut : Curves.ease
                )
              ),
              child: child,
            );
          },
          layoutBuilder: (currentChild, previousChildren) {
            if (isGoingBackwards) {
              // If the user is going backwards through the back stack, display the stack
              // in reverse order so it looks like the top card is lifting off the stack
              return Stack(
                children: [
                  if (currentChild != null) currentChild,
                  ...previousChildren,
                ]
              );
            }
            return Stack( // Forward order
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild
              ]
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_stack.length),
            child: _stack.length > 1 ? 
              Stack(
                children: [
                  SizedBox.expand(child: (_stack.length - 2 >= 0) ? 
                    SheetNavigationContext(scrollController: inactiveScrollController, child: _stack[_stack.length - 2])
                  : null),
                  Dismissible(
                    key: ValueKey(numSteps),
                    direction: DismissDirection.startToEnd,
                    onDismissed: (DismissDirection d) {
                      popWidgetNoAnimation();
                    },
                    child: SizedBox.expand(child: SheetNavigationContext(scrollController: widget.scrollController, child: _stack.last))
                  )
                ]
              )
              : SizedBox.expand(child: SheetNavigationContext(scrollController: widget.scrollController,child: _stack.last,))
            ),
          )
        )
      );
  }
}

// SheetNavigationManager is responsible for all the sheets that open up from the map screen.
// This code used to all live in map_screen.dart, so I wrapped this into a separate class.
// All map_screen has to do is provide some callbacks (onSelectJourney, onSelectStop, etc)
// and SheetNavigationManager figures out the history, back stack, DraggableScrollableSheet stuff, etc.
class SheetNavigationManager {
  PersistentBottomSheetController? _bottomSheetController;

  BuildContext context;

  // These are all callbacks that BusSheet, StopSheet, etc. pass back to map_screen
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

  BusSheet getBusSheet(String busID, ScrollController? scrollController, PushSheet pushNewSheet) {
    return BusSheet(
      busID: busID,
      scrollController: scrollController,
      onSelectStop: (name, id) {
        // When the user clicks on a specific bus stop to open the details (StopSheet) page
        LatLng? latLong = getLatLongFromStopID(id);
        if (latLong != null) {
          pushNewSheet(getStopSheet(id, name, latLong.latitude, latLong.longitude, pushNewSheet, null));
        } else {
          showMaizebusOKDialog(
            contextIn: context,
            title: const Text("Error"),
            content: const Text("Couldn't load stop."),
          );
        }
      },
    );
  }

  void showBusSheetFromMap(String busID) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.85,
        snap: true,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            child: SheetNavigator(
              scrollController: scrollController,
              initialSheetBuilder: (ScrollController scrollControllerLocal, PushSheet pushNewSheet) => getBusSheet(busID, null, pushNewSheet)
            )
          );
        },
      )
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


  StopSheet getStopSheet(String stopID, String stopName, double lat, double long, PushSheet pushSheet, ScrollController? scrollControllerLocal) {
    final busProvider = Provider.of<BusProvider>(context, listen: false);

    return StopSheet(
      stopID: stopID,
      stopName: stopName,
      onFavorite: addFavoriteStop,
      onUnFavorite: removeFavoriteStop,
      scrollController: scrollControllerLocal,
      showBusSheet: (busId) {
        // When someone clicks "See all stops for this bus" this callback runs
        pushSheet(getBusSheet(busId, null, pushSheet));
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
  }

  // Shows a stop sheet from the map by creating a new DraggableScrollableSheet
  void showStopSheetFromMap(
    String stopID,
    String stopName,
    double lat,
    double long,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.85,
        snap: true,
        builder: (BuildContext context, ScrollController scrollController) {
          return SheetNavigator(
            scrollController: scrollController,
            initialSheetBuilder: (ScrollController scrollControllerLocal, PushSheet pushSheet) {
              return getStopSheet(stopID, stopName, lat, long, pushSheet, null);
            }
          );
          
        }
        
      )
    );
  }

}