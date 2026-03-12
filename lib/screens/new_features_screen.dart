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
        autoPlay: true,
        showLiveFullscreenButton: false,
      )
    );

  }

  // Function to handle URL launching
  Future<void> _launchYouTube() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Spacer(),
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
                      const TextSpan(text: "Over the past semester, we've been working to once again revolutionize the way students travel."),
                      const TextSpan(text: " Come see what's new!", style: TextStyle(fontWeight: FontWeight.bold))
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
                
                const SizedBox(height: 25,),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(), 
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: maizeBusBlue,
                    ),
                    onPressed: _launchYouTube,
                    child: const Text(
                      'Watch on YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                )

              ],
            ),
          )
        ),
      )
    );
  }
}