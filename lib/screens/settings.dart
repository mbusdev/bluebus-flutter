import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
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
    
    // Switch(
    //   value: themeProvider.theme == ThemeStyle.dark,
    //   onChanged: (newVal) {
    //     setState(() {
    //       themeProvider.swap();
    //     });
    //   },
    // ),

    // only a Scaffold here to allow the use of Switch within it
    // Otherwise, we could create our own decorated switch widget to use
    return Scaffold(
      backgroundColor: getColor(context, 'background'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 25,
            right: 15,
            top: 10
          ),
          child: Column(
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
            ],
          ),
        )
      )
    );
  }
}