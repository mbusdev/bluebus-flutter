import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';


const FLOOR_SELECTOR_WIDTH = 50.0;
const FLOOR_SELECTOR_ITEM_HEIGHT = 60.0;
const FLOOR_SELECTOR_BORDER_RADIUS = 25.0;
const FLOOR_SELECTED_HIGHLIGHT_MARGIN = 5.0;
class FloorSelector extends StatefulWidget {
  // const FloorSelector

  @override
  State<StatefulWidget> createState() => _FloorSelectorState();
}

class _FloorSelectorState extends State<FloorSelector> {
  List<String> floors = ["1", "2", "3"];
  int selectedIndex = 1;
  double yDragDistance = 0.0;

  void snapToIndex(int index) {
    setState(() {
      yDragDistance = 0;
      selectedIndex = index;
    });
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

  @override
  State<StatefulWidget> createState() => _FloorplanOverlayState();
}

class _FloorplanOverlayState extends State<FloorplanOverlay> {
  List<String> floors = ["1", "2", "3"]; // TODO: Change type as necessary

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: maizeBusBlue,
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
                            "Duderstadt Floor 400",
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


                    FloorSelector(),


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