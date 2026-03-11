import 'package:bluebus/widgets/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

class NewFeaturesScreen extends StatefulWidget {
  const NewFeaturesScreen({super.key});

  @override
  State<NewFeaturesScreen> createState() => _NewFeaturesScreenState();

}

class _NewFeaturesScreenState extends State<NewFeaturesScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(
        controlsVisibleAtStart: true,
        autoPlay: false,
      )
    );

  }

  @override
  Widget build(BuildContext context) {
    ThemeProvider themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    const double heightBetween = 20;

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
                      'New features!',
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
        
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    children: [
                      const TextSpan(text: 'Welcome to '),
                      const TextSpan(text: 'maize', style: TextStyle(color: maizeBusYellow)),
                      TextSpan(text: 'bus', style: TextStyle(color: isDarkMode(context) ? maizeBusBlueDarkMode : maizeBusBlue)),
                      const TextSpan(text: ' 2.0!')
                    ]
                  )
                ),

                const SizedBox(height: 25),

                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 20),
                    children: [
                      const TextSpan(text: "For the past semester, the maizebus team has been redesigning the app to ease your campus navigation experience."),
                      const TextSpan(text: "\n\nMade with love and caffeine. See what's new!", style: TextStyle(fontWeight: FontWeight.bold))
                    ]
                  )
                ),

                const SizedBox(height: 25),

                YoutubePlayer(
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: maizeBusYellow,
                  progressColors: const ProgressBarColors(
                    playedColor: maizeBusYellow,
                    handleColor: maizeBusYellow,
                    bufferedColor: maizeBusBlue
                  ),
                  controller: _controller,
                ),
                

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