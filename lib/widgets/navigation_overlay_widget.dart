
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

class _NavigationOverlayState extends State<NavigationOverlay> 
  implements NavigationOverlayHost {

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
    widget.navigationManager.registerOverlay(this); // does not set to null, see the navigation manager
  }

  @override
  void dispose() { 
    // sets to null 
    widget.navigationManager.unregisterOverlay(this);
    super.dispose();
  }

  @override
  void onNavigationUpdated() { 
    setState(() {
      // called from the nav manager, updates stuff
      updateTimeline();
    });
  }

  // this is the actual Oops code portion
  // not sure if this is how we should have it set up but it is here for now, going to leave a marker 
  // !! TEMP !! 
  @override
  void displayOopsDialog(MissedBus stage) {
    // TODO FOR ALLEN: Make this one a MaizeBusDialogue (Next Updates)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(stage.getTitle()),
        content: Text(stage.getSubtitle()),
      ),
    );
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
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsGeometry.only(left: 10, right: 10, top: 70),
          child: Column(
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
                        "Bus arriving in 218 mins"
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
              // const Spacer(),

              // VVVVVV This is the bottom bar--temporarily commenting it out to repurpose it as a DraggableScrollableSheet

              
                    
                    
                  // )

                    // Padding(
                    //   padding: EdgeInsetsGeometry.only(left: 8),
                    //   child: Text(
                    //     // style: TextStyle(fontSize: 16, color: getColor(context, ColorType.primary)),
                    //     "I'm told your bus is coming"
                    //   ),
                    // )
                    
                //   ],
                // )
              // ),
            ]
          ),
        ),

        // TODO: Add a scrim that fades in when you drag up on the progress bar so that the background is darkened behind the DraggableScrollableSheet
        
        
        DraggableScrollableSheet(
          initialChildSize: 0.12, // TODO: Compute the height of the progress bar dynamically instead of using 12% of screen height as a hardcoded number
          minChildSize: 0.12,
          maxChildSize: 0.85,
          snap: true,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: getColor(context, ColorType.infoCardColor),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [ /* TODO: Add a nice box shadow */ ]
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.all(15),
                children: [
                  // Container(
                
                  // margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                  // padding: EdgeInsets.all(8),
                  
                  // decoration: BoxDecoration(
                  //   color: getColor(context, ColorType.infoCardColor),
                  //   boxShadow: [
                  //     BoxShadow(
                  //       color: getColor(
                  //         context,
                  //         ColorType.mapButtonShadow,
                  //       ),
                  //       blurRadius: 10,
                  //       offset: Offset(0, 6),
                  //     ),
                  //   ],
                  //   borderRadius:
                  //       BorderRadius.circular(25),
                  // ),
                  // child: 

                  // TODO: Figure out why the map panning is so laggy if there's a DraggableScrollableSheet on top

                  // NEXT STEPS TODO: get the steps showing inside the DraggableScrollableSheet and fix the lagging!

                  Row( // Drag handle
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400, // TODO: Make this a real color in constants.dart
                            borderRadius: BorderRadius.circular(1000)
                          ),
                        )
                      )
                    ],
                  ),

                  Column(
                    children: [
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
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 10, right: 10, bottom: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Arrive in 10 mins"),
                            Text("ETA 9:35PM")
                          ],
                        )
                      )
                    ]
                  // )
                  ),

                  Column(
                    children: widget.navigationManager.stageList.map((NavigationStage stage) {
                      return Column(
                        children: stage.getSteps().map((NavigationStageStep step) {
                          return Row(
                            children: [
                              Padding(padding: EdgeInsets.only(left: 20)),
                              Container(
                                decoration: BoxDecoration(
                                  color: step.getColor()
                                ),
                                width: 30,
                                height: 40,
                                child: Container(

                                )
                              ),
                              Padding(padding: EdgeInsets.only(left: 20)),
                              Text(step.getTitle()),
                              // Spacer(),
                              Container(width: 40),
                              Text(step.getTime())
                            ]
                          );
                        }).toList(),
                      );
                      // return Text(stage.getTitle());
                  }).toList(),
                  )
                    
                ]
              )
            );
          }
        ),
      ]
    );
  }

}

// QUESTION: Should navigation_manager



// FUTURE TODO: Add "Connection lost"/"GPS not very accurate" banners to alert the user of those things 
// Some sort of live rotating compass that points to the end of the segment (i.e. if you're walking it replaces the icon and rotates)