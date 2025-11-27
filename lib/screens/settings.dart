import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:bluebus/widgets/building_sheet.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    ThemeProvider themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    const double heightBetween = 20;

    // only a Scaffold here to allow the use of Switch within it,
    // this is because Switch is a Material object and needs to be within a Material element.
    // Otherwise, we could create our own decorated switch widget to use
    return Scaffold(
      backgroundColor: getColor(context, ColorType.background),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 25,
              right: 15,
              top: 15
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Settings title and x button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // title 
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                      ),
                    ),
        
                    // close button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close,),
                    ),
                  ],
                ),
        
                const SizedBox(height: 20),
        
                const Text(
                  'Theme',
                  style: TextStyle(
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: 15),
        
                SegmentedButton(
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.all(0),
                    // shadowColor: Colors.black
                    selectedBackgroundColor: getColor(context, ColorType.highlighted),
                    selectedForegroundColor: getColor(context, ColorType.opposite),
                    backgroundColor: getColor(context, ColorType.dim),
                    side: BorderSide(
                      color: getColor(context, ColorType.background),
                      width: 5,
                      strokeAlign: BorderSide.strokeAlignOutside
                    ),
                  ),
                  expandedInsets: EdgeInsets.symmetric(horizontal: 10),
                  segments: [
                    ButtonSegment(value: ThemeStyle.light, label: Text("light"), icon: Icon(Icons.sunny)),
                    ButtonSegment(value: ThemeStyle.dark, label: Text("dark"), icon: Icon(FontAwesomeIcons.solidMoon)),
                    ButtonSegment(value: ThemeStyle.system, label: Text("system"), icon: Icon(Icons.computer)),
                  ],
                  selected: <ThemeStyle>{themeProvider.theme},
                  onSelectionChanged: (Set<ThemeStyle> selection) {
                    setState(() {
                      themeProvider.setTheme(selection.first);
                    });
                  },
                ),
        
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Team',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    const SizedBox(width: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        sendEmailWithSender(context, 'MaizeBus - Feedback', 'write your feedback here:');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getColor(context, ColorType.dim),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        elevation: 0
                      ),
                      icon: Icon(
                        Icons.email, 
                        color: getColor(context, ColorType.opposite),
                        size: 20,
                      ), // The icon on the left
                      label: Text(
                        'Send Feedback',
                        style: TextStyle(
                          color: getColor(context, ColorType.opposite), 
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ), // The text on the right
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                personShowcase(context, "Ishan Kumar", "Executive Director", "assets/portraits/ishan.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Harvey Kyllonen", "Frontend Lead", "assets/portraits/harvey.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Kate Anderson", "User Interface Lead", "assets/portraits/kate.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Andrew Yu", "Developer Operations Lead", "assets/portraits/andrew.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Ryan Lu", "Backend Lead", "assets/portraits/none.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Matthew Jia", "Developer - Dark Mode", "assets/portraits/matthew.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Isaac Wheeler", "Developer - Bus UI", "assets/portraits/issac.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Edward Zhang", "Developer - Notifications", "assets/portraits/edward.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Aravind Kandarpa", "Developer - City Busses", "assets/portraits/none.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Amanze Aguwa", "Developer - Ann Arbor Map Data", "assets/portraits/amanze.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Siddhant Bhirud", "Developer - Route Preview", "assets/portraits/sid.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Mason Shields", "Developer - Server Caching", "assets/portraits/mason.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Antonio Said", "Logo and Marketing", "assets/portraits/antonio.jpg"),
              ],
            ),
          )
        ),
      )
    );
  }
}


Widget personShowcase(BuildContext context, String name, String role, String filePath) {
  double circleSize = 60.0;
  double lineHeight = 1.2;
  
  return Row(
    children: [
      ClipOval(
        child: Image.asset(
          filePath,
          width: circleSize,
          height: circleSize,
          fit: BoxFit.cover,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 17,
            ),
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                height: lineHeight
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 17,
            ),
            child: Text(
              role,
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w400,
                fontSize: 18,
                color: getColor(context, ColorType.opposite),
                height: lineHeight
              ),
            ),
          ),
        ],
      ),
    ],
  );
}