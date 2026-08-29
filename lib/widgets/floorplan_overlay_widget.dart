// import 'dart:js_interop';

import 'dart:math' as math;
import 'dart:ui';

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/services/floorplan_style.dart';
import 'package:bluebus/services/map_layers/floorplans_layer.dart';
import 'package:bluebus/utils/floorplan_projection.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:haptic_feedback/haptic_feedback.dart';


const FLOOR_SELECTOR_WIDTH = 50.0;
const FLOOR_SELECTOR_ITEM_HEIGHT = 60.0;
const FLOOR_SELECTOR_BORDER_RADIUS = 25.0;
const FLOOR_SELECTED_HIGHLIGHT_MARGIN = 5.0;
class FloorSelector extends StatefulWidget {
  /// Short labels for the floors, in the order they're drawn -- top to bottom.
  final List<String> floors;

  /// Which of [floors] starts out selected.
  final int initialIndex;

  /// Called with the index into [floors] whenever the selection changes.
  final void Function(int index) onFloorSelected;
  final void Function(int index) onFloorPreselected;

  const FloorSelector({
    super.key,
    required this.floors,
    required this.initialIndex,
    required this.onFloorSelected,
    required this.onFloorPreselected
  });

  @override
  State<StatefulWidget> createState() => _FloorSelectorState();
}

class _FloorSelectorState extends State<FloorSelector> {
  late int selectedIndex = widget.initialIndex;
  late int preselectedIndex = widget.initialIndex;
  double yDragDistance = 0.0;

  List<String> get floors => widget.floors;

  void snapToIndex(int index) {
    // A fling can overshoot the ends of the list, so land on the nearest floor
    // that actually exists.
    final int clamped = index.clamp(0, floors.length - 1);
    final bool changed = clamped != selectedIndex;

    setState(() {
      yDragDistance = 0;
      selectedIndex = clamped;
      preselectedIndex = selectedIndex;
    });

    if (changed) widget.onFloorSelected(clamped);
  }
  

  @override
  Widget build(BuildContext context) {
    
    return Container(
      width: FLOOR_SELECTOR_WIDTH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FLOOR_SELECTOR_BORDER_RADIUS),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black,
        //     blurRadius: 10.0,
        //     spreadRadius: 10.0
        //   )
        // ]
      ),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          // debugPrint("y delta: ${details.localPosition.dy}");
          setState(() {
            yDragDistance += details.delta.dy;
            double yPosition = selectedIndex * FLOOR_SELECTOR_ITEM_HEIGHT + yDragDistance;
            if (yPosition < 0) {
              yDragDistance = -1 * selectedIndex * FLOOR_SELECTOR_ITEM_HEIGHT;
              // Lowest allowed value for yDragDistance
            }

            if (yPosition > FLOOR_SELECTOR_ITEM_HEIGHT * (floors.length - 1)) {
              // yDragDistance = FLOOR_SELECTOR_ITEM_HEIGHT * (floors.length - 1);
              yDragDistance = (floors.length - 1 - selectedIndex) * FLOOR_SELECTOR_ITEM_HEIGHT;
              // Highest allowed value for yDragDistance
            }

            double roughIndex = selectedIndex + (yDragDistance / FLOOR_SELECTOR_ITEM_HEIGHT);


            if (preselectedIndex != roughIndex.round()) { // We have a new floor preselected
              preselectedIndex = roughIndex.round();
              widget.onFloorPreselected(preselectedIndex);
            }
              
          });
          
        },
        onVerticalDragEnd: (details) {
          double roughIndex = selectedIndex + (yDragDistance / FLOOR_SELECTOR_ITEM_HEIGHT);
          debugPrint("Rough new index: $roughIndex");
          snapToIndex(roughIndex.round());
        },
        child: Stack(
          children: [

            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              top: selectedIndex * FLOOR_SELECTOR_ITEM_HEIGHT + yDragDistance,
              child: Container(
                width: FLOOR_SELECTOR_WIDTH,
                height: FLOOR_SELECTOR_ITEM_HEIGHT,
                alignment: Alignment.center,
                child: Container(
                  width: FLOOR_SELECTOR_WIDTH - FLOOR_SELECTED_HIGHLIGHT_MARGIN * 2,
                  height: FLOOR_SELECTOR_ITEM_HEIGHT - FLOOR_SELECTED_HIGHLIGHT_MARGIN * 2,
                  decoration: BoxDecoration(
                  color: maizeBusYellow,
                  borderRadius: BorderRadius.circular(FLOOR_SELECTOR_BORDER_RADIUS - FLOOR_SELECTED_HIGHLIGHT_MARGIN)
                ),
                ),
              ),
            ),
            

            Column(
              children: [
                ...floors.asMap().entries.map((entry) {
                  int index = entry.key;
                  String floorNum = entry.value;

                  return InkWell(
                    onTap: () {
                      snapToIndex(index);
                      // setState(() {
                      //   selectedIndex = index;
                      //   yDragDistance = 0;
                      // });
                    },
                    child: Container(
                      width: FLOOR_SELECTOR_WIDTH,
                      height: FLOOR_SELECTOR_ITEM_HEIGHT,
                      alignment: Alignment.center,
                      child: Text(
                        floorNum,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20.0,
                          fontWeight: (selectedIndex == index) ? FontWeight.bold : FontWeight.normal
                        ),
                        
                      ),
                    ),
                  );
                  
                  
                })
              ],
            ),

            
          ],
        )
      )
      
      
      
      
      
    );
  }
}

class FloorplanPreviewPainter extends CustomPainter {
  FloorplanFloor floor;
  bool isActive;

  double scaleFactor;
  double offsetX;
  double offsetY;

  FloorplanPreviewPainter({
    required this.floor,
    required this.isActive,
    required this.scaleFactor,
    required this.offsetX,
    required this.offsetY
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    if (this.isActive) {
      paintActiveFloorBase(canvas, size);
      paintActiveFloorRooms(canvas, size);
    }
    else paintInactiveFloor(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return false;
  }

  void paintActiveFloorBase(Canvas canvas, Size size) {
    
    final fillPaint = Paint()
      ..color = FLOORPLAN_BASE_FILL
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = FLOORPLAN_STROKE
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Path path = Path()..addPolygon(
      floor.outline.map((Offset o) {
        double newX = (o.dx + offsetX) * scaleFactor;
        double newY = (o.dy + offsetY) * scaleFactor;
        // debugPrint("New X and Y: $newX, $newY");
        return Offset(newX, newY);
      }).toList(), true);

    canvas.drawPath(
      path, fillPaint
    );

    canvas.drawPath(
      path,
      strokePaint
    );
  }

  void paintActiveFloorRooms(Canvas canvas, Size size) {
    
    

    final strokePaint = Paint()
      ..color = FLOORPLAN_STROKE
      ..strokeWidth = FLOORPLAN_ROOM_STROKE_WIDTH.toDouble()
      ..style = PaintingStyle.stroke;

    floor.rooms.forEach((FloorplanRoom room) {
      if (room.polygon.length < 3) return; // Skip rooms that aren't sufficiently 2D
      if (room.type == "inaccessible") return;

      final fillPaint = Paint()
      ..color = floorplanRoomFill(room.type) 
      ..style = PaintingStyle.fill;

      Path path = Path()..addPolygon(
        room.polygon.map((Offset o) {
          double newX = (o.dx + offsetX) * scaleFactor;
          double newY = (o.dy + offsetY) * scaleFactor;
          // debugPrint("New X and Y: $newX, $newY");
          return Offset(newX, newY);
        }).toList(), true);

      canvas.drawPath(
        path, fillPaint
      );

      // canvas.drawPath(
      //   path,
      //   strokePaint
      // );
    });
    
  }

  static Path floorOutlineToPath(List<Offset> outline, double scaleFactor, double offsetX, double offsetY) {
    return Path()..addPolygon(
      outline.map((Offset o) {
        double newX = (o.dx + offsetX) * scaleFactor;
        double newY = (o.dy + offsetY) * scaleFactor;
        // debugPrint("New X and Y: $newX, $newY");
        return Offset(newX, newY);
      }).toList(), true);
  }

  void paintInactiveFloor(Canvas canvas, Size size) {

    final fillPaint = Paint()
      ..color = Color(0x4409006b)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // debugPrint("Canvas dimensions are ${size.width} x ${size.height}");
    // debugPrint("Floor outline is ${floor.outline}");

    // canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), strokePaint);

    // debugPrint("Scale factor: $scaleFactor, offset X: $offsetX, Offset Y: $offsetY");

    Path path = floorOutlineToPath(floor.outline, scaleFactor, offsetX, offsetY);

    canvas.drawPath(
      path, fillPaint
    );

    canvas.drawPath(
      path,
      strokePaint
    );
  }
  
}

class FloorOutlineClipper extends CustomClipper<Path> {

  List<Offset> outline;
  double scaleFactor;
  double offsetX;
  double offsetY;

  FloorOutlineClipper({
    required this.outline,
    required this.scaleFactor,
    required this.offsetX,
    required this.offsetY
  });

  @override
  Path getClip(Size size) {
    final path = FloorplanPreviewPainter.floorOutlineToPath(outline, scaleFactor, offsetX, offsetY);
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }

}

class FloorplanOverlay extends StatefulWidget {
  // const FloorplanOverlauy
  Function? onClosed;

  /// The map layer this overlay drives. Picking a floor here is what swaps the
  /// geometry drawn on the map underneath.
  final FloorplansLayer floorplansLayer;

  FloorplanOverlay({
    required this.onClosed,
    required this.floorplansLayer
  });

  @override
  State<StatefulWidget> createState() => _FloorplanOverlayState();
}

class _FloorplanOverlayState extends State<FloorplanOverlay> with TickerProviderStateMixin {
  /// The building's floors ordered the way the selector shows them: the top of
  /// the building at the top of the list. Empty until the floorplan loads.
  List<FloorplanFloor> floors = const [];
  List<FloorplanFloor> alignedFloors = [];
  late final AnimationController _controller;
  late Animation<double> _floorOffset;
  int selectedIndex = 0;
  bool loadFinished = false;
  double scaleFactor = 1; // Overwritten by getScaleFactor

  double offsetX = 0; // Offset X and Y are used to get rid of any extra space on
  double offsetY = 0; //    the top or left side of the floor plan

  FloorplansLayer get layer => widget.floorplansLayer;

  @override
  void initState() {
    super.initState();
    loadFloors();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600)
    );
    _floorOffset = AlwaysStoppedAnimation(selectedIndex.toDouble());
  }

  double getScaleFactor() {
    double maxX = 0;
    double maxY = 0;
    double minX = double.infinity;
    double minY = double.infinity;

    alignedFloors.forEach((FloorplanFloor floor) {
      floor.outline.forEach((Offset point) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      });
    });

    offsetX = -1 * minX;
    offsetY = -1 * minY;

    debugPrint("Context width: ${MediaQuery.sizeOf(context).width}, maxX - offsetX: ${maxX - offsetX}");

    return MediaQuery.sizeOf(context).width / (maxX + offsetX);

    // TODO: Check if this works with really tall floors (it might not)
  }

  /// Rescales and rotates every floor so its waypoints land on the first
  /// floor's waypoint positions, undoing whatever arbitrary pixel scale/angle
  /// each floor was originally drawn at. Floors missing either waypoint are
  /// left untouched -- there's nothing to align them on.
  List<FloorplanFloor> getAlignedFloors(List<FloorplanFloor> floors) {
    if (floors.isEmpty) return floors;

    final FloorplanPoi? refWp1 = floors.first.findPoiByType(FloorplanTypes.waypoint1);
    final FloorplanPoi? refWp2 = floors.first.findPoiByType(FloorplanTypes.waypoint2);
    if (refWp1 == null || refWp2 == null) return floors;

    return [
      for (final floor in floors)
        _alignFloor(floor, targetA: refWp1.position, targetB: refWp2.position),
    ];
  }

  /// Same complex-division trick as [FloorplanProjection.fromControlPoints],
  /// but solved pixel-to-pixel instead of pixel-to-lat/lng -- no y-flip needed
  /// since both floors' plan pixels already grow downward the same way.
  FloorplanFloor _alignFloor(
    FloorplanFloor floor, {
    required Offset targetA,
    required Offset targetB,
  }) {
    final FloorplanPoi? wp1 = floor.findPoiByType(FloorplanTypes.waypoint1);
    final FloorplanPoi? wp2 = floor.findPoiByType(FloorplanTypes.waypoint2);
    if (wp1 == null || wp2 == null) return floor;

    final Offset planA = wp1.position;
    final Offset planB = wp2.position;

    final double planDx = planB.dx - planA.dx;
    final double planDy = planB.dy - planA.dy;
    final double planLengthSquared = planDx * planDx + planDy * planDy;
    if (planLengthSquared == 0) return floor;

    final double targetDx = targetB.dx - targetA.dx;
    final double targetDy = targetB.dy - targetA.dy;

    final double scaleCos = (targetDx * planDx + targetDy * planDy) / planLengthSquared;
    final double scaleSin = (targetDy * planDx - targetDx * planDy) / planLengthSquared;

    Offset transform(Offset point) {
      final double relX = point.dx - planA.dx;
      final double relY = point.dy - planA.dy;
      return Offset(
        targetA.dx + scaleCos * relX - scaleSin * relY,
        targetA.dy + scaleSin * relX + scaleCos * relY,
      );
    }

    return FloorplanFloor(
      id: floor.id,
      name: floor.name,
      pxPerMeter: floor.pxPerMeter,
      width: floor.width,
      height: floor.height,
      walls: [
        for (final wall in floor.walls)
          FloorplanWall(start: transform(wall.start), end: transform(wall.end)),
      ],
      rooms: [
        for (final room in floor.rooms)
          FloorplanRoom(
            id: room.id,
            name: room.name,
            type: room.type,
            polygon: room.polygon.map(transform).toList(),
            poiId: room.poiId,
          ),
      ],
      pois: [
        for (final poi in floor.pois)
          FloorplanPoi(
            id: poi.id,
            position: transform(poi.position),
            type: poi.type,
            name: poi.name,
            roomId: poi.roomId,
            navNodeId: poi.navNodeId,
          ),
      ],
      outline: floor.outline.map(transform).toList(),
      nav: FloorplanNavGraph(
        nodes: [
          for (final node in floor.nav.nodes)
            FloorplanNavNode(id: node.id, position: transform(node.position)),
        ],
        edges: floor.nav.edges,
      ),
    );
  }

  /// The map screen kicks the load off at startup, so this has almost always
  /// finished already -- awaiting it just covers opening the overlay early.
  Future<void> loadFloors() async {
    await layer.load();
    if (!mounted) return;

    final List<FloorplanFloor> ordered = [...layer.floors, ...layer.floors] // Duplicate floors for testing
      ..sort((a, b) => b.level.compareTo(a.level));
    final FloorplanFloor? active = layer.activeFloor;
    final int activeIndex = active == null ? -1 : ordered.indexOf(active);

    setState(() {
      floors = ordered;
      selectedIndex = activeIndex < 0 ? 0 : activeIndex;
      loadFinished = true;

      alignedFloors = getAlignedFloors(floors);
      scaleFactor = getScaleFactor();
    });
  }

  void selectFloor(int index) async {
    // _controller.reset();
    final double oldValue = _floorOffset.value;
    await Haptics.vibrate(HapticsType.medium);
    setState(() {
      selectedIndex = index;
      _floorOffset = Tween<double>(begin: oldValue, end: index.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    });

    _controller.forward(from: 0);
    // The selector works in display order, the layer in the data's own order.
    layer.setFloorIndex(layer.floors.indexOf(floors[index]));
  }

  void preselectFloor(int index) async {
    // _controller.reset();
    final double oldValue = _floorOffset.value;
    await Haptics.vibrate(HapticsType.medium);
    setState(() {
      selectedIndex = index;
      _floorOffset = Tween<double>(begin: oldValue, end: index.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    });

    _controller.forward(from: 0);
    // The selector works in display order, the layer in the data's own order.
    // layer.setFloorIndex(layer.floors.indexOf(floors[index]));
  }

  // void preselectFloor(int index) {
  //   final double oldValue = _floorOffset.value;
  //   setState(() {
  //     _floorOffset = Tween<double>(begin: oldValue, end: index.toDouble())
  //       .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
  //   });
  //   _controller.forward(from: 0);
  // }

  String get building {
    return layer.floorplan?.building ?? "";
  }

  String get floorName {
    return floors[selectedIndex].name;
  }

  String get title {
    if (floors.isEmpty) {
      return loadFinished ? "Floorplan unavailable" : "Loading floorplan...";
    }
    return "${layer.floorplan?.building ?? ''} ${floors[selectedIndex].name}".trim();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            // Transparent so the floorplan the map is drawing underneath shows
            // through -- this overlay is just the chrome around it.
            color: Color(0xFF0B5394),
            // gradient: LinearGradient(
            //   begin: Alignment.topLeft,
            //   end: Alignment(0.8, 1),
            //   colors: <Color>[
            //     Color(0xff1f005c),
            //     Color(0xff5b0060),
            //     Color(0xff870160),
            //     Color(0xffac255e),
            //     Color(0xffca485c),
            //     Color(0xffe16b5c),
            //     Color(0xfff39060),
            //     Color(0xffffb56b),
            //   ], // Gradient from https://learnui.design/tools/gradient-generator.html
            //   tileMode: TileMode.mirror,
            // ),
          ),
          child: Center(


            
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -30 * _floorOffset.value + 100),
                  child: Stack(
                    // alignment: Alignment.center,
                    children: alignedFloors.asMap().entries.map((entry) {
                      //entry.key is the index, entry.value is the FloorplanFloor
                      return 
                          Padding(
                            padding: EdgeInsetsGeometry.only(top: 30 * entry.key.toDouble() ),
                            child: Stack(
                              children: [
                                // ClipPath(
                                //   clipper: FloorOutlineClipper(
                                //     outline: entry.value.outline,
                                //     scaleFactor: scaleFactor * 1.2,
                                //     offsetX: offsetX - (50 / scaleFactor),
                                //     offsetY: offsetY
                                //   ),
                                //   child: BackdropFilter(
                                //     filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                //     child: SizedBox(
                                //       width: MediaQuery.sizeOf(context).width + 200,
                                //       height: 300
                                //       // color: Colors.transparent
                                //     )
                                //   )
                                // ),
                                Transform.scale(
                                  scaleY: 0.75,
                                  child: Transform.rotate(
                                    angle: -1 * math.pi / 4, // 45°, in radians — because of course Flutter didn't give you a degrees param
                                    child: CustomPaint(
                                      size: Size(MediaQuery.sizeOf(context).width + 200, 300),
                                      painter: FloorplanPreviewPainter(
                                        floor: entry.value,
                                        isActive: entry.key == selectedIndex,
                                        scaleFactor: scaleFactor * 1.2,
                                        offsetX: offsetX - (50 / scaleFactor),
                                        offsetY: offsetY
                                      ),
                                    ),
                                  )
                                )

                                
                                
                              ]
                            )    
                      );
                      
                      
                    }).toList().reversed.toList(),
                  ),
                );
              }
            )
            
          ),
        ),

        SafeArea( // Makes sure the contents aren't covered up by the status or navigation bars. TODO: Add this to NavigationOverlayWidget and other widgets as necessary
          child: Column(
            children: [
              Padding(
                padding: EdgeInsetsGeometry.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      icon: Icon(Icons.arrow_back),
                      iconSize: 30,
                      onPressed: () { 
                        widget.onClosed?.call();
                      },
                      style: IconButton.styleFrom(backgroundColor: Colors.white), // TODO: Make this dynamic for light/dark mode
                    ),
                    SizedBox(width: 10,),
                    Spacer()
                    // Expanded(
                    //   child: Container(
                    //     decoration: BoxDecoration(
                    //       color: Colors.white, // TODO: Make dynamic for light/dark mode
                    //       borderRadius: BorderRadius.all(Radius.circular(30))
                    //     ),
                    //     child: Padding(
                    //       padding: EdgeInsetsGeometry.only(left: 20, right: 20, top: 7, bottom: 7),
                    //       child: Text(
                    //         title,
                    //         style: TextStyle(color: Colors.black,),
                    //         textAlign: TextAlign.center,
                    //       ),
                    //     )
                    //   )
                      
                    // )
                  ],
                ),
              ),

              Text(
                building,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Urbanist",
                  fontSize: 40,
                  height: 1
                )
              ),
              Text(
                floorName,
                style: TextStyle(
                  fontSize: 20
                ),
              ),
              
              Spacer(),
              Padding(
                padding: EdgeInsetsGeometry.all(15),
                child: Row(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [


                    // Nothing to pick between until the floorplan has loaded.
                    if (floors.isNotEmpty)
                      FloorSelector(
                        floors: [for (final floor in floors) floor.shortName],
                        initialIndex: selectedIndex,
                        onFloorSelected: selectFloor,
                        onFloorPreselected: preselectFloor,
                      ),


                    // IconButton.filled(
                    //   icon: Icon(Icons.layers),
                    //   iconSize: 30,
                    //   onPressed: () { 

                    //   },
                    //   style: IconButton.styleFrom(backgroundColor: Colors.white), // TODO: Make this dynamic for light/dark mode
                    // ),
                    SizedBox(width: 8,),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // TODO: Make dynamic for light/dark mode
                          borderRadius: BorderRadius.all(Radius.circular(30))
                        ),
                        child: Padding(
                          padding: EdgeInsetsGeometry.only(left: 20, right: 20, top: 10, bottom: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.black,
                                size: 30,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "Room #",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18
                                ),
                                
                              ),
                            ],
                          )
                          
                          
                        )
                      )
                      
                    )

                  ],
                )
              )
            ] 
          ),
        )
        
      ],
    );
  }

}