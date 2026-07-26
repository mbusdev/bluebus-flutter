
import 'package:bluebus/constants.dart';
import 'package:bluebus/services/journey_repository.dart';
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
          child: Column( // Core column for vertical layout
            children: [
              MaterialButton(
                color: Colors.blue.shade900,
                child: Text("Init stages from /plan-journey"),
                onPressed: () async {
                  final journeys = await JourneyRepository.planJourney(
                    originLat: 42.274014,
                    originLon: -83.753664,
                    destLat: 42.297493,
                    destLon: -83.710782,
                  );

                  // Use journeys[0] to get the first one

                  widget.navigationManager.initFromJourney(journeys[0]);


                }
              ),


              Row( // Top header row
                children: [
                  Expanded(
                  child:
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                      decoration: BoxDecoration(
                        // color: getColor(context, ColorType.mapButtonPrimary),
                        color: Color.fromARGB(255, 187, 187, 187),
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
                          Container( // The big white card at the top
                          
                            // margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
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
                                size: 30,
                              ),
                              // Expanded(
                                
                                // child: 
                              Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getColor(context, ColorType.mapButtonIcon)),
                                      widget.navigationManager.getCurrentStage().getTitle()
                                    ),
                                    // Text(
                                    //   style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                                    //   widget.navigationManager.getCurrentStage().getSubtitle()
                                    // ),
                                  ]
                                )
                              ),

                              // )
                            ]
                          )
                        ),
                          Container( // The smaller bottom protrusion from the big white card
                            
                            padding: EdgeInsets.only(top: 10, bottom: 10, left: 20, right: 20),
                            
                            
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pool,
                                  size: 20,
                                  color: getColor(context, ColorType.mapButtonIcon)
                                ),
                                SizedBox.square(dimension: 10,),
                                Text(
                                  "Then turn left",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: getColor(context, ColorType.mapButtonIcon)
                                  )
                                )
                              ],
                            )
                          )
                      ]
                      )
                    )
                    
                  ),
                  SizedBox.square(dimension: 10.0,),
                  Container( 
                
                    margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                    padding: EdgeInsets.all(16),
                    
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
                    child: Column(
                      children: [
                        RouteIcon.small("BB"),
                        Text(
                          "3 min",
                          style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                          ),
                        Text(
                          "arrival",
                          style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                        )
                        // Padding(
                        //   padding: EdgeInsetsGeometry.only(left: 8),
                        //   child: Text(
                        //     style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                        //     "Bus arriving in 218 mins"
                        //   ),
                        // ),
                        // MaterialButton(
                        //   minWidth: 50,
                        //   onPressed: () {
                        //     setState(() {
                        //       widget.navigationManager.previousStage();
                        //       updateTimeline();
                        //     });
                        //   },
                        //   child: Icon(Icons.arrow_back, color: Colors.white),
                        // ),
                        // MaterialButton(
                        //   minWidth: 50,
                        //   onPressed: () {
                        //     setState(() {
                        //       widget.navigationManager.nextStage();
                        //       updateTimeline();
                        //     });
                        //   },
                        //   child: Icon(Icons.arrow_forward, color: Colors.white)
                        // )
                        
                        
                        
                      ],
                    )
                  ),
                ],
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

                  SizedBox.square(dimension: 20.0,),

                  // TODO: Filter by user location!! Only show the future steps(?)
                  // TODO: Also show stage titles in this list

          
                  Column(
                    
                    children: widget.navigationManager.stageList.asMap().entries.map((entry) {

                      int index = entry.key;
                      NavigationStage stage = entry.value;

                      bool shouldRoundTopCorners = (index == 0) || stage.hasRoundedCorners();

                      return Column(
                        children: [
                          
                          Row(
                              children: [
                                Padding(padding: EdgeInsets.only(left: 20)),
                                Container( // Gray background behind colorful line segment
                                  width: 30,
                                  height: 50,
                                  decoration: (index != 0) ? BoxDecoration(
                                    color: getColor(context, ColorType.navigationStepsGray)
                                  ) : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: stage.getColor(),
                                      borderRadius: BorderRadius.only(
                                        topLeft: shouldRoundTopCorners ? Radius.circular(20) : Radius.circular(0),
                                        topRight: shouldRoundTopCorners ? Radius.circular(20) : Radius.circular(0),
                                      )
                                    ),
                                  ),
                                ),
                                
                                Padding(padding: EdgeInsets.only(left: 20)),
                                Text(
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold
                                  ),
                                  stage.getTitle()
                                ),
                                // Spacer(),
                                Container(width: 40),
                                // Text(stage.g())
                              ]
                            ),

                          ...stage.getSteps().asMap().entries.map((entry) {
                            int sub_index = entry.key;
                            NavigationStageStep step = entry.value;
                            // NEXT STEPS TODO: Get the border radius working on only the first and last items


  // NEXT STEPS TODO: get live location showing on the step list, as well as properly rounded corners (see the Figma) and bigger dots on the first/last segments, etc. Also get subtitles working

                            bool shouldRoundBottomCorners = false;

                            if (index == widget.navigationManager.stageList.length - 1 && sub_index == stage.getSteps().length - 1) {
                              shouldRoundBottomCorners = true;
                            }
                            
                            if (stage.hasRoundedCorners() && sub_index == stage.getSteps().length - 1) {
                              shouldRoundBottomCorners = true;
                            }

                            return Row(
                              children: [
                                Padding(padding: EdgeInsets.only(left: 20)),
                                Container( // Gray background behind colorful line segment
                                  width: 30,
                                  height: 40,
                                  decoration: (index != widget.navigationManager.stageList.length - 1) ? BoxDecoration(
                                    // Only show the gray background if the box shouldn't have a rounded bottom (i.e. isn't at the end of the stage list)
                                    color: getColor(context, ColorType.navigationStepsGray)
                                  ) : null,
                                  child: Container( // Colorful line segment
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: step.getColor(),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero,
                                        bottomRight: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero
                                      )
                                    ),
                                    
                                    child: Container( // Inside dot or dash
                                      width: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 4,
                                      height: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 16,
                                      // color: Colors.white,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.all(Radius.circular(100))
                                      ),
                                      // color: Colors.white
                                    )
                                  ),
                                ),
                                Padding(padding: EdgeInsets.only(left: 20)),
                                Text(step.getTitle()),
                                // Spacer(),
                                Container(width: 40),
                                Text(step.getTime())
                              ]
                            );
                          }).toList()
                        ],
                      );
                      // return Text(stage.getTitle());
                  }).toList(),
                  )
                    
              // )
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