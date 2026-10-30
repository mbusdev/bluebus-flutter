import 'package:bluebus/services/floorplan_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../constants.dart';
import 'package:flutter/material.dart';

class POISheet extends StatefulWidget {
  final String name;
  final ValueListenable<LocatedFloorplanPoi?> poiSelected;
  final bool showBottomRoomNumber;
  final bool hasResults;

  const POISheet({
    Key? key,
    required this.name,
    required this.poiSelected,
    required this.showBottomRoomNumber,
    required this.hasResults
  }) : super(key: key);
  
  @override
  State<POISheet> createState() => _POISheetState();
}

class _POISheetState extends State<POISheet> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20,),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 0
                  ),
                ),

                // listen to POI selected changes
                ValueListenableBuilder<LocatedFloorplanPoi?>(
                  valueListenable: widget.poiSelected,
                  builder: (context, poi, child) {
                    // user has not selected a POI yet, then show nothing
                    if (poi == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: double.infinity, height: 10,),
                          Text(
                            widget.hasResults ? "Tap on an icon to see more info." : "No results were found near you.", 
                            style: TextStyle(fontSize: 16, color: getColor(context, ColorType.opposite))
                          ),
                          SizedBox(width: double.infinity, height: 40,)
                        ]
                      );
                    }
                    
                    return Column(

                      children: [
                        SizedBox(width: double.infinity, height: 15,),
                        const Divider(),
                        SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Selected", style: TextStyle(fontSize: 16, color: getColor(context, ColorType.roomSearchText))),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      if (widget.showBottomRoomNumber)
                                        TextSpan(
                                          text: poi.poi.name,
                                          style: TextStyle(
                                            fontSize: 18, 
                                            fontWeight: FontWeight.bold,
                                            color: getColor(context, ColorType.opposite)
                                          ),
                                        ),

                                      if (widget.showBottomRoomNumber)
                                        TextSpan(text: " on ", style: TextStyle(fontSize: 18, color: getColor(context, ColorType.opposite))),

                                      TextSpan(
                                        text: poi.floor.name,
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold,
                                          color: getColor(context, ColorType.opposite)
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: getColor(context, ColorType.importantButtonBackground),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                elevation: 0,
                              ),
                              child: Text(
                                'Get Directions',
                                style: TextStyle(
                                  color: getColor(context, ColorType.importantButtonText),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16
                                ),
                              ),
                            ),
                            
                          ],
                        ),

                        SizedBox(width: double.infinity, height: 40,)
                      ],
                    );
                  },
                ),
              ]
            )
          ),
        ],
      )
    );
  }
}