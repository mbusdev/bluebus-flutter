import 'package:flutter/material.dart';

class FloorplanOverlay extends StatefulWidget {
  // const FloorplanOverlauy

  @override
  State<StatefulWidget> createState() => _FloorplanOverlayState();
}

class _FloorplanOverlayState extends State<FloorplanOverlay> {


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment(0.8, 1),
              colors: <Color>[
                Color(0xff1f005c),
                Color(0xff5b0060),
                Color(0xff870160),
                Color(0xffac255e),
                Color(0xffca485c),
                Color(0xffe16b5c),
                Color(0xfff39060),
                Color(0xffffb56b),
              ], // Gradient from https://learnui.design/tools/gradient-generator.html
              tileMode: TileMode.mirror,
            ),
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
                  children: [
                    IconButton.filled(
                      icon: Icon(Icons.layers),
                      iconSize: 30,
                      onPressed: () { 

                      },
                      style: IconButton.styleFrom(backgroundColor: Colors.white), // TODO: Make this dynamic for light/dark mode
                    ),
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