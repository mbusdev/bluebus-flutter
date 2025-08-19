import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/bus_repository.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bus.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart'; 
import 'package:intl/intl.dart';

class StopSheet extends StatefulWidget {
  final String stopID;
  final String stopName;

  const StopSheet({
    Key? key,
    required this.stopID,
    required this.stopName
  }) : super(key: key);

  @override
  State<StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends State<StopSheet> {
  late Future<List<BusWithPrediction>> arrivingBuses;

  @override
  void initState() {
    super.initState();
    arrivingBuses = fetchNextBusArrivals(widget.stopID);
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
            // header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.stopName,
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      height: 0
                    ),
                  ),
                ),

                SizedBox(width: 15,),

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
                            widget.stopID,
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
            ),

            SizedBox(height: 20,),
            
            // future data
            FutureBuilder<List<BusWithPrediction>>(future: arrivingBuses, 
              builder: (context, snapshot) {
                
                String futureTime(String minutesInFuture){
                  int min = int.parse(minutesInFuture);
                  DateTime now = DateTime.now();
                  DateTime futureTime = now.add(Duration(minutes: min));
                  return DateFormat('hh:mm a').format(futureTime);
                }

                String format(String text) {
                  if (text == null || text.isEmpty) {
                    return '';
                  }

                  // Capitalize the first character and lowercase the rest
                  return text[0].toUpperCase() + text.substring(1).toLowerCase();
                }
              
                if (snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (snapshot.data!.length == 0)? "There are currently no departing busses" : "Next bus departures",
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                        ),
                      ),
          
                      SizedBox(height: 10,),
            
                      ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), 
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            BusWithPrediction bus = snapshot.data![index];
                        
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: RouteColorService.getRouteColor(bus.id), 
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          bus.id,
                                          style: TextStyle(
                                            color: RouteColorService.getContrastingColor(bus.id), 
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      
                                      SizedBox(width: 15,),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              getPrettyRouteName(bus.id),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Urbanist',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              )
                                            ),

                                            Text(
                                              (bus.prediction != "DUE")? "${format(bus.direction)}, est: ${futureTime(bus.prediction)}" : "within the next minute",
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Urbanist',
                                                fontWeight: FontWeight.w400,
                                                fontSize: 16,
                                              )
                                            )
                                          ],
                                        ),
                                      ),

                                      (bus.prediction != "DUE")?
                                      Column(
                                        children: [
                                          Text(
                                            bus.prediction,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 20,
                                              height: 0
                                            )
                                          ),
                                          Text(
                                            "min",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 14,
                                              height: 0
                                            )
                                          )
                                        ],
                                      ) : SizedBox.shrink()
                                    ],
                                  ),
                                ],
                              );
                          },
                          separatorBuilder: (context, index) {
                            return Divider();
                          },
                        ),

                      // two bottom buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); 
                              //widget.onGetDirections(widget.building);
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

                          Spacer(),

                          ElevatedButton.icon(
                            onPressed: () {
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
                              Icons.favorite_border, 
                              color: Colors.black,
                              size: 20,), // The icon on the left
                            label: const Text(
                              'Add to Favorites',
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
                  );
                } 
            
                else if (snapshot.hasError) {
                  return Text(
                    "There doesn't seem to be any departure data for this stop",
                    style: TextStyle(
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w400,
                      fontSize: 20,
                    ),
                  );
                }
                
                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
      )
    );
  }
} 