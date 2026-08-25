import 'package:bluebus/constants.dart';
import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/services/map_layers/floorplans_layer.dart';
import 'package:flutter/material.dart';


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

  const FloorSelector({
    super.key,
    required this.floors,
    required this.initialIndex,
    required this.onFloorSelected,
  });

  @override
  State<StatefulWidget> createState() => _FloorSelectorState();
}

class _FloorSelectorState extends State<FloorSelector> {
  late int selectedIndex = widget.initialIndex;
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
                      debugPrint("Clicked!");
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

class _FloorplanOverlayState extends State<FloorplanOverlay> {
  /// The building's floors ordered the way the selector shows them: the top of
  /// the building at the top of the list. Empty until the floorplan loads.
  List<FloorplanFloor> floors = const [];
  int selectedIndex = 0;
  bool loadFinished = false;

  FloorplansLayer get layer => widget.floorplansLayer;

  @override
  void initState() {
    super.initState();
    loadFloors();
  }

  /// The map screen kicks the load off at startup, so this has almost always
  /// finished already -- awaiting it just covers opening the overlay early.
  Future<void> loadFloors() async {
    await layer.load();
    if (!mounted) return;

    final List<FloorplanFloor> ordered = [...layer.floors]
      ..sort((a, b) => b.level.compareTo(a.level));
    final FloorplanFloor? active = layer.activeFloor;
    final int activeIndex = active == null ? -1 : ordered.indexOf(active);

    setState(() {
      floors = ordered;
      selectedIndex = activeIndex < 0 ? 0 : activeIndex;
      loadFinished = true;
    });
  }

  void selectFloor(int index) {
    setState(() {
      selectedIndex = index;
    });
    // The selector works in display order, the layer in the data's own order.
    layer.setFloorIndex(layer.floors.indexOf(floors[index]));
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
            color: Colors.transparent,
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
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // TODO: Make dynamic for light/dark mode
                          borderRadius: BorderRadius.all(Radius.circular(30))
                        ),
                        child: Padding(
                          padding: EdgeInsetsGeometry.only(left: 20, right: 20, top: 7, bottom: 7),
                          child: Text(
                            title,
                            style: TextStyle(color: Colors.black,),
                            textAlign: TextAlign.center,
                          ),
                        )
                      )
                      
                    )
                  ],
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