import 'package:bluebus/services/bus_info_service.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/route_color_service.dart';
import '../models/bus_stop.dart'; 
import 'package:intl/intl.dart';
                          
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

class MiniStopSheet extends StatefulWidget {
  final String stopID;
  final String stopName;
  final void Function() onUnfavorite;
  final void Function() onTapOnThis;

  const MiniStopSheet({
    Key? key,
    required this.stopID,
    required this.stopName,
    required this.onUnfavorite,
    required this.onTapOnThis
  }) : super(key: key);

  @override
  State<MiniStopSheet> createState() => _MiniStopSheetState();
}

class _MiniStopSheetState extends State<MiniStopSheet> {
  late Future<(List<BusWithPrediction>, bool)> loadedStopData;

  @override
  void initState() {
    super.initState();
    loadedStopData = fetchStopData(widget.stopID);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: FutureBuilder(
        future: loadedStopData,
        builder: (context, snapshot) {
          List<BusWithPrediction> arrivingBuses = [];
          
          if (snapshot.hasData){
            arrivingBuses = snapshot.data!.$1;
          }
          
          if (snapshot.hasData) {
            return GestureDetector(
              onTap: (){
                widget.onTapOnThis();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.stopName,
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Urbanist',
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              height: 0
                            ),
                          ),
                        ),

                        SizedBox(width: 14,),

                        GestureDetector(
                          onTap: () {
                            widget.onUnfavorite();
                          },
                          child: Icon(Icons.delete_outline)
                        )
                      ],
                    ),

                    SizedBox(height: 14,),
                    
                    (arrivingBuses.length != 0)?
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: (arrivingBuses.length > 3)? 3 : arrivingBuses.length,
                      itemBuilder: (context, index) {
                        BusWithPrediction bus = arrivingBuses[index];
                    
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
                                  child: MediaQuery(
                                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
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
                                        (bus.prediction != "DUE")? "est: ${futureTime(bus.prediction)}" : "within the next minute",
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
                    ): Text("No upcoming busses", style: TextStyle(fontWeight: FontWeight.w400, fontSize: 20,))
                  ],
                ),
              ),
            );

          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 30),
              child: Center(child: CircularProgressIndicator()),
            );

          } else {
            return Text("couldn't load info for ${widget.stopName}");
          }
        }
      ),
    );
  }
} 