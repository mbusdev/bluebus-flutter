import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';


void sendEmailWithSender(BuildContext context, String locName) async {
  final Email email = Email(
    body: 'write the issue here:',
    subject: 'MaizeBus - Issue with $locName',
    recipients: ['ishaniik@umich.edu'],
    isHTML: false,
  );

  try {
    await FlutterEmailSender.send(email);
  } catch (error) {
    showFallbackOptions(context);
  }
}

void showFallbackOptions(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          'Email-Send failed',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Urbanist',
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        content: Text(
          'Unable to reach the email app on your device. You can still send us feedback by manually emailing ishaniik@umich.edu',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Urbanist',
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

// Selecting routes
class BuildingSheet extends StatefulWidget {
  final Location building;
  final void Function(Location) onGetDirections;

  const BuildingSheet({
    Key? key,
    required this.building,
    required this.onGetDirections
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20,),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.building.name,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 40,
                height: 0
              ),
            ),
          ),
      
          SizedBox(width: double.infinity, height: 5,),
      
          // show different subtitle depending on whether one exists
          (widget.building.abbrev != "")?
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
            ),
          ) : 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text("No building code",
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w400,
                fontSize: 20,
              ),
            ),
          ),
      
          SizedBox(height: 20,),
      
          // two bottom buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); 
                  widget.onGetDirections(widget.building);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: maizeBusDarkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      
              ElevatedButton.icon(
                onPressed: () {
                  sendEmailWithSender(context, widget.building.name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 235, 235, 235),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      
          SizedBox(height: 30,)
        ],
      )
    );
  }
} 