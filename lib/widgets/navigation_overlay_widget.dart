
import 'package:bluebus/constants.dart';
import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';

class NavigationOverlay extends StatefulWidget {

  final NavigationManager navigationManager;

  const NavigationOverlay({
    super.key,
    required this.navigationManager
  });

  // TODO: add an "update callback register" command so that our NavigationManager can reach into the NavigationOverlayWidget and the map and tell them to update.

  @override
  State<StatefulWidget> createState() => _NavigationOverlayState();

}

class _NavigationOverlayState extends State<NavigationOverlay> {

  TimelineInfo timelineInfo = TimelineInfo();

  void updateTimeline() { // Call this after all the stages are loaded (or stages change)
    // debugPrint("***** Updating timeline!");
    timelineInfo = widget.navigationManager.getTimeline();
    // debugPrint("***** Timeline now has ${timelineSteps.length} things!");
  }

  @override
  void initState() {
    // debugPrint("HELLO YELLO WE ARE IN IN/ITSTATE");
    super.initState();
    updateTimeline();
  }

  @override
  Widget build(BuildContext context) {
    // switch (widget.navigationManager.getCurrentStage()) {
    //   case NavOnBus():
    //     // Do stuff
      
    //   case NavWalking():
    //     // TODO: Handle this case.
    //     throw UnimplementedError();
    // }
    return Column(

      children: [
      
        Container(
          width: double.infinity,
          
          margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
          padding: EdgeInsets.all(20),
          
          decoration: BoxDecoration(
            color: getColor(context, ColorType.mapButtonPrimary),
            boxShadow: [
              BoxShadow(
                color: getColor(
                  context,
                  ColorType.mapButtonShadow,
                ),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius:
                BorderRadius.circular(25),
          ),
          child: Row(children: [
            Icon(
              Icons.pool,
              color: getColor(context, ColorType.mapButtonIcon),
              size: 48,
            ),
            Expanded(
              
              child: 
              Padding(
                padding: EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getColor(context, ColorType.mapButtonIcon)),
                      widget.navigationManager.getCurrentStage().getTitle()
                    ),
                    Text(
                      style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                      widget.navigationManager.getCurrentStage().getSubtitle()
                    ),
                  ]
                )
              )
            )
          ])
        ),

  
        Container( // I have absolutely no idea how to shrink this to fit the content. Thanks Flutter
          
          margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
          padding: EdgeInsets.all(8),
          
          decoration: BoxDecoration(
            color: getColor(context, ColorType.mapButtonPrimary),
            boxShadow: [
              BoxShadow(
                color: getColor(
                  context,
                  ColorType.mapButtonShadow,
                ),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius:
                BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              RouteIcon.small("BB"),
              Padding(
                padding: EdgeInsetsGeometry.only(left: 8),
                child: Text(
                  style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                  "I'm told your bus is coming"
                ),
              ),
              MaterialButton(
                minWidth: 50,
                onPressed: () {
                  setState(() {
                    widget.navigationManager.previousStage();
                    updateTimeline();
                  });
                },
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              MaterialButton(
                minWidth: 50,
                onPressed: () {
                  setState(() {
                    widget.navigationManager.nextStage();
                    updateTimeline();
                  });
                },
                child: Icon(Icons.arrow_forward, color: Colors.white)
              )
              
              
              
            ],
          )
        ),

        // Expanded(child: SizedBox.expand()),
        // SizedBox.expand(),

        Container( // I have absolutely no idea how to shrink this to fit the content. Thanks Flutter
          
          margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
          padding: EdgeInsets.all(8),
          
          decoration: BoxDecoration(
            color: getColor(context, ColorType.infoCardColor),
            boxShadow: [
              BoxShadow(
                color: getColor(
                  context,
                  ColorType.mapButtonShadow,
                ),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius:
                BorderRadius.circular(25),
          ),
          child: Column(
            children: [
              // TODO: Add the user's position in all of this
              // ClipRRect(
              //   borderRadius: BorderRadius.circular(12),

                // child: 
                LayoutBuilder(
                  builder: (context, constraints) {

                    const double dotSize = 24.0;
                    final double dotLeft = (constraints.maxWidth * this.timelineInfo.activePositionPercentage) - (dotSize / 2);


                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: dotSize, bottom: dotSize),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                          
                            children: this.timelineInfo.timelineSteps.map((item) {
                                return Flexible(
                                  flex: item.estimated_time.floor(), // Proportionally sizes to each item's time
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(color: item.color),
                                  )
                                );
                                // return Container(
                                //   width: MediaQuery.of(context).size.width * item.percentage,
                                //   height: 10,
                                //   decoration: BoxDecoration(color: item.color),
                                // );
                              }).toList(),
                              // Container(
                              //   width: MediaQuery.of(context).size.width * 0.3,
                              //   height: 10,
                              //   decoration: BoxDecoration(color: Colors.green),
                              // ),
                              // Container(
                              //   width: MediaQuery.of(context).size.width * 0.3,
                              //   height: 10,
                              //   decoration: BoxDecoration(color: Colors.red),
                              // ),
                              // Container(
                              //   width: MediaQuery.of(context).size.width * 0.3,
                              //   height: 10,
                              //   decoration: BoxDecoration(color: Colors.green),
                              // ),
                          ),
                        ),
                      ),
                      

                      // Text("HIIIIIII THIS IS A TEST ${dotLeft}, pos %: ${this.timelineInfo.activePositionPercentage}"),

                      // Container(
                      //     width: dotSize, 
                      //     height: dotSize, 
                      //     decoration: const BoxDecoration(
                      //       color: Colors.red, 
                      //       shape: BoxShape.circle
                      //     ),
                      //   ),
                    
                      Positioned( // TODO: Make this thing animate smoooooothly!
                        left: dotLeft,
                        // top: -dotSize / 4,
                        // top: -dotSize,
                        child: Container(
                          width: dotSize, 
                          height: dotSize, 
                          decoration: BoxDecoration(
                            color: Color(0xFF4286F5), 
                            border: Border.all(
                              color: Colors.white,
                              // color: Color(0x666896DD),
                              width: 2.0
                            ),
                            boxShadow: [
                              BoxShadow(color: Color(0x666896DD), spreadRadius: 16)
                            ],
                            shape: BoxShape.circle
                          ),
                        ),
                      )
                    ],
                  );
                }
              )
            // )

              // Padding(
              //   padding: EdgeInsetsGeometry.only(left: 8),
              //   child: Text(
              //     // style: TextStyle(fontSize: 16, color: getColor(context, ColorType.primary)),
              //     "I'm told your bus is coming"
              //   ),
              // )
              
            ],
          )
        ),
      ]
    );
  }

}

// QUESTION: Should navigation_manager



// FUTURE TODO: Add "Connection lost"/"GPS not very accurate" banners to alert the user of those things 
// Some sort of live rotating compass that points to the end of the segment (i.e. if you're walking it replaces the icon and rotates)