
import 'dart:math';

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/journey_repository.dart';
import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  bool planJourneyInProgress = false;
  TimelineInfo timelineInfo = TimelineInfo();

  void updateTimeline() { // Call this after all the stages are loaded (or stages change)
    timelineInfo = widget.navigationManager.getTimeline();
  }

  @override
  void initState() {
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

  // the regular busOptions button 
  Widget busOptionButton(
    Bus bus, 
    VoidCallback onTap
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: bus.routeColor,
                child: Text(bus.routeId, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bus.id,
                  style: const TextStyle(decoration: TextDecoration.underline, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFC94A), borderRadius: BorderRadius.circular(10)),
                child: Text("1", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), // NOTE: Mock using number 1, need to double check with Bus class
              ),
            ],
          ),
        ),
      ),
    );
  }

  // making this reusable, bit unecessary but if you need a red button with text!
  Widget missedBusButton(VoidCallback onTap, Text text) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: text, // using passed in text parameter 
      ),
    ); // the beautiful pill of doom and despair
  }

  // The code below should diplay the "which bus are you on" popup from UI Team 
  // Should currently show (#4) (Version of the design..)
  @override
  void displayOopsDialog() {
    showUndismissableMaizebusDialog(
      contextIn: context,
      title: Text("Which bus are you on?"),
      // Builder so the buttons below get a context underneath the dialog route and can pop it
      content: Builder(
        builder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10.0,
          children: [ // All of this data is currently placeholder
            busOptionButton(Bus(id: "1234",
                                position: LatLng(12.1, 12.1),
                                routeId: "NES",
                                heading: 12.0,
                                fullness: "67%",
                                routeColor: Color.fromARGB(255, 9, 9, 239)),
                                () {
                                  debugPrint("Oops dialog: picked bus 1234 (NES)");
                                  Navigator.pop(dialogContext);
                                }),
            busOptionButton(Bus(id: "5678",
                                position: LatLng(12.1, 12.1),
                                routeId: "BB",
                                heading: 12.0,
                                fullness: "67%",
                                routeColor: Color.fromARGB(255, 9, 9, 239)),
                                () {
                                  debugPrint("Oops dialog: picked bus 5678 (BB)");
                                  Navigator.pop(dialogContext);
                                }),
            missedBusButton(() {
              debugPrint("Oops dialog: user missed the bus");
              Navigator.pop(dialogContext);
            }, Text("I missed the bus"))
          ],
        )
      )
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
              // MaterialButton(
              //   color: Colors.blue.shade900,
              //   child: Text(planJourneyInProgress ? "Loading..." : "Init stages from /plan-journey"),
              //   onPressed: () async {
              //     setState(() {
              //       planJourneyInProgress = true;
              //     });
              //     try {
              //       // Try both forwards and reverse directions
              //       final fut1 = JourneyRepository.planJourney(
              //         originLat: 42.274014,
              //         originLon: -83.753664,
              //         destLat: 42.297493,
              //         destLon: -83.710782,
              //       );
              //       final fut2 = JourneyRepository.planJourney(
              //         originLat: 42.297493,
              //         originLon: -83.710782,
              //         destLat: 42.274014,
              //         destLon: -83.753664,
              //       );
              //       final journeys = (await Future.wait([fut1, fut2]))
              //         .expand((x) => x)
              //         .toList();

              //       // Pick a random journey
              //       widget.navigationManager.initFromJourney(journeys[Random().nextInt(journeys.length)]);
              //     } finally {
              //       setState(() {
              //         planJourneyInProgress = false;
              //       });
              //     }
              //   }
              // ),


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
            
              MaterialButton(
                color: Colors.red.shade900,
                child: Text("Show Oops dialog"),
                onPressed: () => widget.navigationManager.showOopsDialog(),
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
                                
                                Padding(padding: EdgeInsets.only(left: 15)),
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
  // NEXT STEPS TODO: get live location showing on the step list

                            bool shouldRoundBottomCorners = false;

                            if (index == widget.navigationManager.stageList.length - 1 && sub_index == stage.getSteps().length - 1) {
                              shouldRoundBottomCorners = true;
                            }
                            
                            if (stage.hasRoundedCorners() && sub_index == stage.getSteps().length - 1) {
                              shouldRoundBottomCorners = true;
                            }

                            return Stack(
                              
                              children: [
                                Positioned(
                                  left: 10,
                                  top: 0,
                                  bottom: 0,
                                  width: 30,
                                  child: Container( // Gray background behind colorful line segment
                                    width: 30,
                                    // height: 40,
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
                                ),
                                
                                Padding(
                                  padding: EdgeInsetsGeometry.only(top: 10, bottom: 10, left: 55),
                                  child: Row(
                                    children: [
                                      // Padding(padding: EdgeInsets.only(left: 20)),
                                      
                                      // Padding(padding: EdgeInsets.only(left: 20)),
                                      Expanded(
                                        child: Text(step.getTitle() + step.getTitle()),
                                      ),
                                      
                                      // // Spacer(),
                                      // Container(width: 40),
                                      Text(step.getTime())
                                    ]
                                  )
                                )
                                
                              ],
                            );

                            // return Row(
                            //   children: [
                            //     Padding(padding: EdgeInsets.only(left: 20)),
                            //     Container( // Gray background behind colorful line segment
                            //       width: 30,
                            //       height: 40,
                            //       decoration: (index != widget.navigationManager.stageList.length - 1) ? BoxDecoration(
                            //         // Only show the gray background if the box shouldn't have a rounded bottom (i.e. isn't at the end of the stage list)
                            //         color: getColor(context, ColorType.navigationStepsGray)
                            //       ) : null,
                            //       child: Container( // Colorful line segment
                            //         alignment: Alignment.center,
                            //         decoration: BoxDecoration(
                            //           color: step.getColor(),
                            //           borderRadius: BorderRadius.only(
                            //             bottomLeft: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero,
                            //             bottomRight: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero
                            //           )
                            //         ),
                                    
                            //         child: Container( // Inside dot or dash
                            //           width: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 4,
                            //           height: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 16,
                            //           // color: Colors.white,
                            //           decoration: BoxDecoration(
                            //             color: Colors.white,
                            //             borderRadius: BorderRadius.all(Radius.circular(100))
                            //           ),
                            //           // color: Colors.white
                            //         )
                            //       ),
                            //     ),
                            //     Padding(padding: EdgeInsets.only(left: 20)),
                            //     Expanded(
                            //       child: Text(step.getTitle() + step.getTitle()),
                            //     ),
                                
                            //     // // Spacer(),
                            //     // Container(width: 40),
                            //     Text(step.getTime())
                            //   ]
                            // );



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