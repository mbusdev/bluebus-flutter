import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    ThemeProvider themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // only a Scaffold here to allow the use of Switch within it,
    // this is because Switch is a Material object and needs to be within a Material element.
    // Otherwise, we could create our own decorated switch widget to use
    return Scaffold(
      backgroundColor: getColor(context, 'background'),
      body: SafeArea(
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
                'Appearance',
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
                textAlign: TextAlign.left,
              ),
              
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Dark mode',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w400,
                        fontSize: 18,
                      ),
                    ),
                    Switch(
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (newVal) {
                        setState(() {
                          themeProvider.swap(context);
                        });
                      },
                      activeThumbColor: getColor(context, 'opposite'),
                      activeTrackColor: getColor(context, 'highlighted'),
                    ),
                  ],
                )
              ),

              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w400,
                        fontSize: 18,
                      ),
                    ),
                    
                    DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: getColor(context, 'mapButtonShadow'),
                            blurRadius: 4,
                            offset: const Offset(0, 1)
                          ),
                        ],
                        borderRadius: BorderRadius.circular(56),
                      ),
                      child: DropdownMenu(
                        inputDecorationTheme: InputDecorationTheme(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(56),
                            borderSide: BorderSide.none
                          ),
                          fillColor: getColor(context, 'dim'),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20),
                        ),
                        initialSelection: themeProvider.theme,
                        textStyle: TextStyle(
                          color: getColor(context, 'opposite'),
                          shadows: [
                            Shadow(
                              color: getColor(context, 'mapButtonShadow'),
                              offset: const Offset(0, 2),
                              blurRadius: 4
                            ),
                          ],
                        ),
                        dropdownMenuEntries: [
                          DropdownMenuEntry(value: ThemeStyle.light, label: "light"),
                          DropdownMenuEntry(value: ThemeStyle.dark, label: "dark"),
                          DropdownMenuEntry(value: ThemeStyle.system, label: "system"),
                        ],
                        onSelected: (ThemeStyle? selected) {
                          setState(() {
                            themeProvider.setTheme(selected!);
                          });
                        },
                      ),
                    ),
                  ],
                )
              ),
              
              const SizedBox(height: 20),

              SegmentedButton(
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.all(0),
                  // shadowColor: Colors.black
                  selectedBackgroundColor: getColor(context, 'highlighted'),
                  selectedForegroundColor: getColor(context, 'opposite'),
                  backgroundColor: getColor(context, 'dim'),
                  side: BorderSide(
                    color: getColor(context, 'background'),
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
            ],
          ),
        )
      )
    );
  }
}