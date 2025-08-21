import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/bus_repository.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bus.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart'; 
import 'package:intl/intl.dart';

class BusSheet extends StatefulWidget {
  final String busID;
  final void Function(String name, String id) onSelectStop;

  const BusSheet({
    Key? key,
    required this.busID,
    required this.onSelectStop
  }) : super(key: key);

  @override
  State<BusSheet> createState() => _BusSheetState();
}

class _BusSheetState extends State<BusSheet> {
  late Bus currBus = BusRepository.getBus(widget.busID)!;
  late Future<List<BusStopWithPrediction>> futureBusStops;

  @override
  void initState() {
    super.initState();
    futureBusStops = fetchNextBusStops(widget.busID);
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currBus.routeColor, 
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    currBus.routeId,
                    style: TextStyle(
                      color: RouteColorService.getContrastingColor(currBus.routeId), 
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(width: 15,),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getPrettyRouteName(currBus.routeId),
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                      ),
                    ),
                    Text(
                      "Bus ${currBus.id}",
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 20,),
            
            // future data
            FutureBuilder<List<BusStopWithPrediction>>(future: futureBusStops, 
              builder: (context, snapshot) {
                
                String futureTime(String minutesInFuture){
                  int min = int.parse(minutesInFuture);
                  DateTime now = DateTime.now();
                  DateTime futureTime = now.add(Duration(minutes: min));
                  return DateFormat('hh:mm a').format(futureTime);
                }
              
                if (snapshot.hasData) {

                  // bus times aren't sorted for some reason
                  snapshot.data!.sort((a, b) {
                    // sorting function

                    // edge cases
                    if (a.prediction == "DUE"){
                      return -1;
                    }
                    if (b.prediction == "DUE"){
                      return 1;
                    }

                    int idA = int.parse(a.prediction);
                    int idB = int.parse(b.prediction);
                    return idA.compareTo(idB);
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Next bus stops",
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                        ),
                      ),
          
                      SizedBox(height: 10,),

                      // only show list with no data
                      (snapshot.data!.length != 0)?
                      ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), 
                          itemCount: (snapshot.data!.length > 6)? 6 : snapshot.data!.length,
                          itemBuilder: (context, index) {
                            BusStopWithPrediction stop = snapshot.data![index];
                        
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context); 
                                      widget.onSelectStop(stop.name, stop.id);
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(255, 235, 235, 235),
                                        borderRadius: BorderRadius.all(Radius.circular(15)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color.fromARGB(95, 187, 187, 187), 
                                            spreadRadius: 1.5, 
                                            blurRadius: 2, 
                                            offset: Offset(0, 3), 
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 15, right: 15, top: 9, bottom: 9),
                                        child: Row(
                                          children: [
                                            
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    stop.name,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'Urbanist',
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 16,
                                                    )
                                                  ),
                                    
                                                  // add subtitle if not due
                                                  (stop.prediction != "DUE")?
                                                  Text(
                                                    "Estimated: ${futureTime(stop.prediction)}",
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'Urbanist',
                                                      fontWeight: FontWeight.w400,
                                                      fontSize: 16,
                                                    )
                                                  ) : SizedBox.shrink()
                                                ],
                                              ),
                                            ),
                                            
                                            SizedBox(width: 20, height: 0,),
                                            
                                            (stop.prediction != "DUE")?
                                            Column(
                                              children: [
                                                Text(
                                                  stop.prediction,
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
                                            ) 
                                            :
                                            Column(
                                              children: [
                                                Text(
                                                  "now",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 20,
                                                    height: 0
                                                  )
                                                ),
                                              ],
                                            ) 
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                        
                                  SizedBox(height: 15,),
                                ],
                              );
                          },
                        ):
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            "There don't appear to be any upcoming stops for this bus",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                              height: 0
                            )
                          ),
                        )
                    ],
                  );
                } 
            
                else if (snapshot.hasError) {
                  return Text(
                    "There doesn't seem to be any departure data for this bus",
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