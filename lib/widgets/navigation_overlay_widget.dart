
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
                      // "I don't know, dude, figure it out"
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: Row(
                  children: [ // Navigation sections
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 10,
                      decoration: BoxDecoration(color: Colors.green),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 10,
                      decoration: BoxDecoration(color: Colors.red),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 10,
                      decoration: BoxDecoration(color: Colors.green),
                    ),
                  ],
                )
              )

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