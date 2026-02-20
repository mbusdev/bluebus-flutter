import 'package:bluebus/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:bluebus/globals.dart';


void sendEmailWithSender(BuildContext context, String emailSubject, String emailBody) async {
  final Email email = Email(
    body: emailBody,
    subject: emailSubject,
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
  showMaizebusOKDialog(
    contextIn: context,
    title: const Text("Email-Send failed"),
    content: const Text("Unable to reach the email app on your device. You can still send us feedback by manually emailing contact@maizebus.com"),
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
            child: Text(
              widget.building.name,
              style: TextStyle(
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
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w400,
                fontSize: 20,
              ),
            ),
          ),
      
          SizedBox(height: 20,),
      
          // two bottom buttons
          Padding(
            padding: EdgeInsets.only(left: globalLeftRightPadding, right: globalLeftRightPadding, bottom: globalBottomPadding),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); 
                      widget.onGetDirections(widget.building);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getColor(context, ColorType.importantButtonBackground),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap
                    ),
                    icon:  Icon(
                      Icons.directions, 
                      color: getColor(context, ColorType.importantButtonText),
                      size: 20,
                    ),
                    label: Text(
                      'Directions',
                      style: TextStyle(
                        color: getColor(context, ColorType.importantButtonText),
                        fontSize: 16, 
                        fontWeight: FontWeight.w600,
                      ),
                    ), // The text on the right
                  ),
                ),
            
                SizedBox(width: globalLeftRightPadding,),
                  
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(contactURL),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getColor(context, ColorType.secondaryButtonBackground),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap
                    ),
                    icon: Icon(
                      Icons.report, 
                      color: getColor(context, ColorType.secondaryButtonText),
                      size: 20,
                    ), // The icon on the left
                    label: Text(
                      'Feedback',
                      style: TextStyle(
                        color: getColor(context, ColorType.secondaryButtonText), 
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis
                      ),
                    ), // The text on the right
                  ),
                ),
                  
              ],
            ),
          ),
        ],
      )
    );
  }
} 