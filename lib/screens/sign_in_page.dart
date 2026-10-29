import 'package:bluebus/globals.dart';
import 'package:bluebus/widgets/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {

  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse("https://www.google.com")
      );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: getColor(context, ColorType.background),
      appBar: AppBar(
        title: const Text("Sign in with U-M"),
      ),
      body: WebViewWidget(
        controller: _controller
      )
      // body: SingleChildScrollView(
      //   child: SafeArea(
      //     child: Padding(
      //       padding: const EdgeInsets.only(
      //         left: 25,
      //         right: 25,
      //         top: 15
      //       ),
      //       child: Column(
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         children: [
      //           // Settings title and x button
      //           Row(
      //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //             crossAxisAlignment: CrossAxisAlignment.center,
      //             children: [
      //               // title 
      //               Text(
      //                 'Sign In',
      //                 style: TextStyle(
      //                   fontFamily: 'Urbanist',
      //                   fontWeight: FontWeight.w700,
      //                   fontSize: 30,
      //                 ),
      //               ),
        
      //               // close button
      //               IconButton(
      //                 onPressed: () => Navigator.pop(context),
      //                 icon: Icon(Icons.close,),
      //               ),

      //               WebViewWidget(
      //                 controller: _controller
      //               )
      //             ],
      //           ),
      //         ],
      //       ),
      //     )
      //   ),
      // )
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