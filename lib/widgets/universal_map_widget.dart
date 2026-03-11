import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/models/bus_stop.dart';
import 'package:bluebus/services/map_image_service.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as LatLongNew;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide TileLayer;
import 'package:google_maps_flutter/google_maps_flutter.dart' as GMaps;
import '../constants.dart';
import 'package:path_provider/path_provider.dart';


class UniversalMapController {
  UniversalMapWidgetState? _widget;
  List<BusRouteLine>? routesToApply; // Used for when MapScreen's _loadAllData calls setBusRouteLines before the UniversalMapWidget is created. The routes are temporarily stored here before being passed to the widget when it's available
  List<Bus>? newBusesToApply;
  List<Bus>? changedBusesToApply;

  void setBusRouteLines(List<BusRouteLine> allLinesIn) {
    if (_widget == null) {
      routesToApply = allLinesIn;
    } else {
      _widget?.setBusRouteLines(allLinesIn);
    }
  }

  void connectToWidget(UniversalMapWidgetState widget) {
    _widget = widget;
    if (routesToApply != null) {
      _widget?.setBusRouteLines(routesToApply!);
      _widget?.regeneratePolylines();
      routesToApply = null;
    }
    if (newBusesToApply != null) {
      widget.updateBusPositions(newBusesToApply!, changedBusesToApply!);
      newBusesToApply = null;
      changedBusesToApply = null;
    }
  }

  // TODO: Add a setFavoriteStops method

  void setRouteFilter(Set<String> selectedRoutes) {
    // selectedRoutes is a Set of all the routes the user has selected.
    // When this function is called, store selectedRoutes to a state variable
    // and change the stored set of routesToDisplay and stopsToDisplay
    // Also filter out stops
    debugPrint("Setting route filter! Got ${selectedRoutes.length} routes");
    _widget?.selectedRoutes = selectedRoutes;
    _widget?.regeneratePolylines();
    _widget?.regenerateStaticMarkers();
    debugPrint("Finished setting route filter!");
  }

  void updateBusPositions(List<Bus> newBuses, List<Bus> changedBuses) {
    debugPrint("Inside the controller, got updateBusPositions call. widget = ${_widget}");
    final widget = _widget;
    if (widget == null) {
      newBusesToApply = newBuses;
      changedBusesToApply = changedBuses;
      return;
    }
    widget.updateBusPositions(newBuses, changedBuses);
  }
  
  

  // Future<void> loadCustomMarkers() async {
  //   debugPrint("Inside UniversalMapController loadCustomMarkers(), widget is ${_widget}");
  //   _widget?.loadCustomMarkers();
  // }

  // Some sort of function that looks at routesToDisplay and stopsToDisplay
  // and compiles polylinesToDisplay and marketsToDisplay
  
}

// TODO: Add a function to convert a stops List (i.e. List<BusStop> MapScreen._stopsByRoute)
// if (!_routeStopMarkers.containsKey(routeKey)) {
//         _routeStopMarkers[routeKey] = r.stops
//             .map(
//               (stop) => Marker(
//                 markerId: MarkerId('stop_${stop.id}_${r.points.hashCode}'),
//                 position: stop.location,
//                 icon: _favoriteStops.contains(stop.id)
//                     ? (_favStopIcon ??
//                           _stopIcon ??
//                           BitmapDescriptor.defaultMarkerWithHue(
//                             BitmapDescriptor.hueAzure,
//                           ))
//                     : (_stopIcon ??
//                           BitmapDescriptor.defaultMarkerWithHue(
//                             BitmapDescriptor.hueAzure,
//                           )),
//                 consumeTapEvents: true,
//                 onTap: () {
//                   try {
//                     Haptics.vibrate(HapticsType.light);
//                   } catch (e) { }
                  
//                   _showStopSheet(
//                     stop.id,
//                     stop.name,
//                     stop.location.latitude,
//                     stop.location.longitude,
//                   );
//                 },
//               ),
//             )
//             .toSet();
//       }

class UniversalMapWidgetState extends State<UniversalMapWidget> {
  //final _controller = Completer<GoogleMapController>();
  // final 

  List<BusRouteLine> _allLines = [];
  // List<BusStop> _stopsToDisplay = [];
  Set<String> selectedRoutes = {};
  Set<Polyline> polylinesToDisplay = {};
  List<Polyline> new_polylinesToDisplay = [];
  Set<Marker> staticMarkersToDisplay = {};
  List<Marker> new_staticMarkersToDisplay = [];
  MapImageService imageService = MapImageService();

  Map<String,Bus> liveBuses = {};
  Map<String,Marker> animatableMarkersToDisplay = {};

  Style? style;

  void loadCustomMarkers() {
    debugPrint("Loading custom markers!!");
    imageService.loadCustomMarkers(() {
      regeneratePolylines();
      regenerateStaticMarkers();
    });
  }

  Future<void> loadSelectedRoutesFromStorage(Function() callback) async {
      // Load selected routes from persistent storage
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedRoutes = Set.from(prefs.getStringList('selected_routes') ?? []);
      callback();
    });
  }

  late final Future<PmTilesVectorTileProvider> _futureLocalTileProvider;

  @override
  void initState() {
    widget.universalController.connectToWidget(this);
    loadSelectedRoutesFromStorage(() {
      loadCustomMarkers();
    });
    
    _futureLocalTileProvider = _loadLocalTileProvider();
    
    StyleReader(
      uri:
          'https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json?api_key={key}',
      apiKey: "6a898d9f-ce94-41d5-a7fc-dd414ee3dfe1",
      logger: Logger.console()
    ).read().then((style) {
      this.style = style;
      setState(() {});
    });

    super.initState();
  }

  Future<PmTilesVectorTileProvider> _loadLocalTileProvider() async {
    // TODO: Save this to storage so this only needs to run once per install.
    // Right now it's re-writing the map data to cache every time the app loads
    final bytes = await rootBundle.load('assets/cache.pmtiles');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cache.pmtiles');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return await PmTilesVectorTileProvider.fromSource(file.path);
  }

  
  
  void setBusRouteLines(List<BusRouteLine> allLinesIn) {
    _allLines = allLinesIn;
  }

  void regeneratePolylines() {
    debugPrint("regeneratePolylines() call, currently have ${selectedRoutes.length} routes selected");
    debugPrint("    allLines has ${_allLines.length} lines");
    // Convert _allLines, filtered with selectedRoutes, into polylinesToDisplay
    // Future: Also incorporate currently displayed journey, if the user is in navigation mode
    setState(() {
      // polylinesToDisplay.clear();
      new_polylinesToDisplay.clear();
      _allLines.forEach((BusRouteLine line) {
        // debugPrint(selectedRoutes.first);
        if (selectedRoutes.contains(line.routeId)) {
          // debugPrint("Route should be shown!!");
          final routeKey = '${line.routeId}_${line.points.hashCode}';
          final routeColor = line.color ?? RouteColorService.getRouteColor(line.routeId);
          
          
          new_polylinesToDisplay.add(
            Polyline(
              points: line.points.map((GMaps.LatLng item) {
                // Convert Google Maps LatLng to Flutter Maps LatLng
                // Both classes sharing the same name is giving me a grand headache
                return LatLongNew.LatLng(item.latitude, item.longitude);
              }).toList(),
              color: routeColor,
              strokeWidth: 6,
              strokeJoin: StrokeJoin.round,
              borderStrokeWidth: 6,
              borderColor: Colors.white)
          );
          // polylinesToDisplay.add(Polyline(
          //   polylineId: PolylineId(routeKey),
          //   points: line.points,
          //   color: routeColor,
          //   width: 4,
          // ));
        }
        // debugPrint("Adding new polylines! ${polylinesToDisplay}");
      });
    });
  }

  void regenerateStaticMarkers() {
    debugPrint("Regenerating static markers...");

    // TODO: Maybe update route bus icons? Use _loadRouteBusIcon in the MapImageService

    setState(() {
      _allLines.forEach((BusRouteLine line) {
        if (selectedRoutes.contains(line.routeId)) {

          line.stops.forEach((BusStop stop) {
            new_staticMarkersToDisplay.add(
              Marker(
                point: LatLongNew.LatLng(stop.location.latitude, stop.location.longitude),
                width: 20,
                height: 20,
                child: GestureDetector(
                  onTap: () {
                    widget.onStopClicked(stop);
                  },
                  child: SizedBox(
                    width: 2.0,
                    height: 2.0,
                    child: Image.asset("assets/bus_stop.png", width: 2.0, height: 2.0)
                  ),
                )
                
                
                
                 
              )

              // NEXT STEPS TODO: Get the bitmaps working for icons! We can even do cool click animations!!!!!
              // Also figure out what's causing the vector map crash

              // Marker(
              //   markerId: MarkerId('stop_${stop.id}_${line.points.hashCode}'),
              //   position: stop.location,
              //   icon: imageService.stopIcon, // TODO: Track favorite stops and change the icon
              //   // icon: _stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
              //   // icon: _favoriteStops.contains(stop.id) 
              //   //     ? (_favStopIcon ??
              //   //           _stopIcon ??
              //   //           BitmapDescriptor.defaultMarkerWithHue(
              //   //             BitmapDescriptor.hueAzure,
              //   //           ))
              //   //     : (_stopIcon ??
              //   //           BitmapDescriptor.defaultMarkerWithHue(
              //   //             BitmapDescriptor.hueAzure,
              //   //           )),
              //   consumeTapEvents: true,
              //   onTap: () {
              //     widget.onStopClicked(stop);
              //   },
              // ),
            );

          });


          
          // line.stops.forEach((BusStop stop) {
          //   staticMarkersToDisplay.add(
          //     Marker(
          //       markerId: MarkerId('stop_${stop.id}_${line.points.hashCode}'),
          //       position: stop.location,
          //       icon: imageService.stopIcon, // TODO: Track favorite stops and change the icon
          //       // icon: _stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
          //       // icon: _favoriteStops.contains(stop.id) 
          //       //     ? (_favStopIcon ??
          //       //           _stopIcon ??
          //       //           BitmapDescriptor.defaultMarkerWithHue(
          //       //             BitmapDescriptor.hueAzure,
          //       //           ))
          //       //     : (_stopIcon ??
          //       //           BitmapDescriptor.defaultMarkerWithHue(
          //       //             BitmapDescriptor.hueAzure,
          //       //           )),
          //       consumeTapEvents: true,
          //       onTap: () {
          //         widget.onStopClicked(stop);
          //       },
          //     ),
          //   );

          //});

        }
      });

      debugPrint("Added ${staticMarkersToDisplay.length} static markers");
    });

    
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Is dark mode? ${isDarkMode(context)}");
    return RepaintBoundary(
      child: (style != null) ? 
      
      FutureBuilder<PmTilesVectorTileProvider>(
        future: _futureLocalTileProvider,
        builder: (BuildContext context, AsyncSnapshot<PmTilesVectorTileProvider> snapshot) {
          if (snapshot.hasError) return Text("Error: ${snapshot.error}");
          if (!snapshot.hasData) return Text("Not ready yet");
          return FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 13.0,
              maxZoom: 18,
              backgroundColor: isDarkMode(context) ? Colors.black : Colors.white,
              interactionOptions: InteractionOptions(
                enableMultiFingerGestureRace: true,
                rotationThreshold: 20.0,
              )
            ),
            children: [
              // TileLayer( // Bring your own tiles
              //   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // For demonstration only
              //   userAgentPackageName: 'com.maizebus.app'/*'com.example.app'*/, // Add your app identifier
              //   // And many more recommended properties!
              // ),

              // isDarkMode(context) ?
              VectorTileLayer(
                tileProviders: TileProviders({
                  'protomaps': snapshot.data!
                }),
                theme: ProtomapsThemes.lightV4(logger: const Logger.console()),
                // TODO: Figure out how to erase the cache for switching between light and dark modes
                layerMode: VectorTileLayerMode.raster,
              ),
                // ) :
                // VectorTileLayer(
                //   tileProviders: TileProviders({
                //     'protomaps': snapshot.data!
                //   }),
                //   theme: ProtomapsThemes.lightV4(logger: const Logger.console()),
                //   layerMode: VectorTileLayerMode.raster,
                // ),
              
              // VectorTileLayer(
              //   tileProviders: style!.providers,
              //   theme: style!.theme,
              //   tileOffset: TileOffset.DEFAULT,
              //   // layerMode: VectorTileLayerMode.raster,
              // ),
              PolylineLayer(
                polylines: new_polylinesToDisplay,
              ),
              MarkerLayer(markers: new_staticMarkersToDisplay),
            ],
          );
        }
      )
      
       : Text("No style (yet!)")
    );
  }

  // Marker getMarkerForBus(Bus b) {
  //   // return Marker(
  //   //   icon: imageService.getIconForBus(b),
  //   //   markerId: MarkerId('bus_${b.id}'),
  //   //   position: b.position,
  //   //   rotation: b.heading,
  //   //   anchor: const Offset(0.5,0.5),
  //   //   onTap:() {
  //   //     widget.onBusClicked(b);
  //   //   },
  //   // );
  // }
  
  void updateBusPositions(List<Bus> newBuses, List<Bus> changedBuses) {
    debugPrint("Got updateBusPositions call! newBuses has ${newBuses.length}, changedBuses has ${changedBuses.length}");

    setState(() {
      changedBuses.forEach((Bus b) {
        debugPrint("Updating changed bus ${b.id} ${b.position}");
        if (!liveBuses.containsKey(b.id)) {
          newBuses.add(b);
          return; // If we don't have a record of this bus, treat it like a new bus
        }

        // animatableMarkersToDisplay[b.id] = getMarkerForBus(b);

      });

      newBuses.forEach((Bus b) {
        debugPrint("Updating new bus ${b.id} ${b.position}");
        // animatableMarkersToDisplay[b.id] = getMarkerForBus(b);
      });

    });

  }
}

class UniversalMapWidget extends StatefulWidget {
  final LatLongNew.LatLng initialCenter = LatLongNew.LatLng(42.277849, -83.7352536);
  // final Set<Polyline> polylines;
  // final Set<Marker> markers;
  // final void Function(GoogleMapController)? onMapCreated;
  // final void Function(CameraPosition)? onCameraMove;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  Function(BusStop stop) onStopClicked;
  Function(Bus bus) onBusClicked;
  
  
  final UniversalMapController universalController;
  
  UniversalMapWidget({
    super.key,
    // required this.polylines,
    // required this.markers,
    // this.onMapCreated,
    // this.onCameraMove,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = true,
    this.mapToolbarEnabled = true,
    required this.universalController,
    required this.onStopClicked,
    required this.onBusClicked
  });
  
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return UniversalMapWidgetState();
  }

  
} 



// NEXT STEPS TODO: Move all of the "map management stuff" logic out of map_screen and into universal_map_widget?
//      Make ONE provider inside map_screen. When the provider updates, have it send the list of updated buses to the UniversalMapWidget via the UniversalMapController
//        When the universal_map_widget receives an update from the provider, it checks the provider's _changed_buses list and only updates those buses with smooth animations, update their positions and animate accordingly
//      Or maybe make a separate class that takes in raw bus data and spits out markers and polylines?
//      Also in the provider, add a "Last updated time" property to each bus



// TODO: Favorite stops
// TODO: Journey overlay
// TODO: Live bus positions
// TODO: In the bus_provider, keep a last-seen-in-the-API timestamp
// TODO: Get rid of old buses (i.e buses that haven't been seen in a while)