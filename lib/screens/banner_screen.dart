import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ProgressCirclePainter extends CustomPainter {

  DateTime startTime;
  DateTime endTime;
  DateTime currentTime;

  ProgressCirclePainter({
    required this.startTime,
    required this.endTime,
    required this.currentTime
  });

  @override
  void paint(Canvas canvas, Size size) {

    double percentage = 1 - (currentTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch)
        / (endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch);
    double pi = 3.1415926;

    var paint = Paint()
      ..color = maizeBusYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    // canvas.drawCircle(
    //   Offset(size.width / 2, size.height / 2),
    //   size.width / 2, paint);

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5 * pi,
      2 * pi * percentage,
      false, paint);

    // TODO: implement paint
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    // throw UnimplementedError();
    return false;
  }

}

class BannerScreen extends StatefulWidget {
  String url;

  BannerScreen({
    super.key,
    required this.url
  });

  @override
  State<BannerScreen> createState() => _BannerScreenState();

}

class _BannerScreenState extends State<BannerScreen> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();

    debugPrint("Showing URL ${widget.url}");

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(widget.url)
      );

  }

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: getColor(context, ColorType.background),
      appBar: AppBar(
        title: const Text("")
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
      //             crossAxisAlignment: CrossAxisAlignment.center,
      //             children: [
      //               Spacer(),
      //               // close button
      //               IconButton(
      //                 onPressed: () => Navigator.pop(context),
      //                 icon: Icon(Icons.close,),
      //               ),
      //             ],
      //           ),
        
      //           const SizedBox(height: 20),
        
                

      //         ],
      //       ),
      //     )
      //   ),
      // )
    );
  }
}