import 'package:bluebus/widgets/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
              right: 25,
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

                LayoutBuilder(
                  builder: (context, constraints) {
                    return MaizebusSlidingSegmentedControl(
                      labels: ["Light", "Dark", "System"], 
                      height: 40,
                      width: constraints.maxWidth,
                      selectedIndex: themeProvider.theme == ThemeStyle.light ? 0 : themeProvider.theme == ThemeStyle.dark ? 1 : 2,
                      onSelectionChanged: (int index) {
                        setState(() {
                          if(index == 0) {
                            themeProvider.setTheme(ThemeStyle.light);
                          } else if(index == 1) {
                            themeProvider.setTheme(ThemeStyle.dark);
                          } else {
                            themeProvider.setTheme(ThemeStyle.system);
                          }
                        });
                      }
                    );
                  }
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
                      onPressed: () => launchUrl(contactURL),
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
                personShowcase(context, "Ishan Kumar", "Executive Director", "assets/portraits/ishan.jpg", cropHeightOffset: -0.1),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Andrew Yu", "Developer Operations Lead", "assets/portraits/andrew.jpg", cropHeightOffset: -0.2),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Kate Anderson", "User Interface Lead", "assets/portraits/kate.jpg", cropHeightOffset: -0.1),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Harvey Kyllonen", "Frontend Lead", "assets/portraits/harvey.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Isaac Wheeler", "Developer - Flow and UI", "assets/portraits/issac.jpg", cropHeightOffset: -0.2),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Matthew Jia", "Developer - Dark Mode and UI", "assets/portraits/matthew.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Edward Zhang", "Developer - Notifications", "assets/portraits/edward.jpg", cropHeightOffset: -0.2),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Siddhant Bhirud", "Developer - Route Preview", "assets/portraits/sid.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Antonio Said", "Bus Graphics and Marketing", "assets/portraits/antonio.jpg", cropHeightOffset: -0.2),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Ryan Lu", "Backend Lead", "assets/portraits/none.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Aravind Kandarpa", "Developer - City Busses Backend", "assets/portraits/none.jpg"),

                const SizedBox(height: heightBetween),
                personShowcase(context, "Evan Huang", "Developer - Movable Routes", "assets/portraits/none.jpg"),
              ],
            ),
          )
        ),
      )
    );
  }
}


Widget personShowcase(BuildContext context, String name, String role, String filePath, {double cropHeightOffset = 0.0}) {
  double circleSize = 55.0;
  double lineHeight = 1.2;
  
  return Row(
    children: [
      ClipOval(
        child: Image.asset(
          filePath,
          width: circleSize,
          height: circleSize,
          fit: BoxFit.cover,
          alignment: Alignment(0.0, cropHeightOffset),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 15,
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
                left: 15,
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  color: getColor(context, ColorType.opposite),
                  height: lineHeight,
                  overflow: TextOverflow.ellipsis
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}