import 'package:bluebus/widgets/journey_search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/journey.dart';
import '../services/journey_repository.dart';
import '../widgets/journey_results_widget.dart';
import '../constants.dart';


// Selecting routes
class BuildingSheet extends StatefulWidget {
  final Location building;

  const BuildingSheet({
    Key? key,
    required this.building,
  }) : super(key: key);

  @override
  State<BuildingSheet> createState() => _BuildingSheetState();
}

// State for the route selector
class _BuildingSheetState extends State<BuildingSheet> {

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.building.name,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 40,
                height: 0
              ),
            ),

            SizedBox(width: double.infinity, height: 5,),

            // show different subtitle depending on whether one exists
            (widget.building.abbrev != "")?
            Row(
              children: [
                Text("Building code: ",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                  ),
                ),
                Column(
                  children: <Widget>[
                    IntrinsicWidth(
                      stepWidth: 20,
                      child: Container(
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            widget.building.abbrev,
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Urbanist',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ) : 
            Text("No building code",
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w400,
                fontSize: 20,
              ),
            ),

            SizedBox(height: 20,),

            // two bottom buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Add your button's functionality here
                    print('Button pressed!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maizeBusDarkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    elevation: 4
                  ),
                  icon: const Icon(
                    Icons.directions, 
                    color: Colors.white,
                    size: 20,), // The icon on the left
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 16, fontWeight: 
                      FontWeight.w600),
                  ), // The text on the right
                ),

                SizedBox(width: 15,),

                ElevatedButton.icon(
                  onPressed: () {
                    // Add your button's functionality here
                    print('Button pressed!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 235, 235, 235),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                  icon: const Icon(
                    Icons.warning_amber_rounded, 
                    color: Colors.black,
                    size: 20,), // The icon on the left
                  label: const Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Colors.black, 
                      fontSize: 16, fontWeight: 
                      FontWeight.w600),
                  ), // The text on the right
                ),

              ],
            ),

            SizedBox(height: 10,)
          ],
        ),
      )
    );
  }
} 