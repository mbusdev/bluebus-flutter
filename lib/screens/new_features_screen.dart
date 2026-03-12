import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:bluebus/providers/theme_provider.dart';
import 'package:provider/provider.dart';
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
    Provider.of<ThemeProvider>(context, listen: false);

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