import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class LoadingScreen extends StatelessWidget {
  final Loadpoint loadpoint;

  const LoadingScreen ({super.key, 
    required this.loadpoint
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Spacer(flex: 5),

          //bus + road + maizebus logo
          SizedBox(
            height: 180,
            child: Center(
              child: OverflowBox(
                maxWidth: MediaQuery.of(context).size.width + 500,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    //maizebus text
                    Container(
                      alignment: Alignment.topCenter,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: maizeBusYellow,
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w800,
                            fontSize: 50,
                          ),
                          children: [
                            TextSpan(text: 'maize'),
                            TextSpan(
                              text: 'bus',
                              style: TextStyle(color: maizeBusBlue),
                            ),
                          ],
                        ),
                      ),
                    ),

                    //grey road
                    Container(
                      alignment: Alignment.bottomCenter,

                      child: Container(
                        height: 40,
                        color: getColor(context, ColorType.dim),
                      ),
                    ),

                    //animated parts
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      height: 180,
                      bottom: 0,
                      right:
                          (MediaQuery.of(context).size.width + 200) * 
                          (1 - (loadpoint.step / 5)),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          //blender that greys-out maizebus
                          Container(
                            padding: EdgeInsets.only(right: 7),
                            alignment: Alignment.topLeft,
                            child: Container(
                              width: 50,
                              height: 50,
                              alignment: Alignment.topLeft,
                              child: OverflowBox(
                                maxWidth:
                                    MediaQuery.of(context).size.width + 250,
                                maxHeight: 50,
                                alignment: Alignment.topLeft,
                                child: ClipPath(
                                  clipper: TrapezoidClipReversed(),
                                  child: Container(
                                    height: 50,
                                    width:
                                        MediaQuery.of(context).size.width +
                                        250,
                                    decoration: BoxDecoration(
                                      color: getColor(
                                        context,
                                        ColorType.background,
                                      ),
                                      backgroundBlendMode:
                                          BlendMode.saturation,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    
                          Container(
                            padding: EdgeInsets.only(right: 7),
                            alignment: Alignment.bottomRight,
                            child: ClipPath(
                              clipper: TrapezoidClip(),
                              child: Container(
                                height: 40,
                                width:
                                    MediaQuery.of(context).size.width + 250,
                                color: maizeBusYellow,
                              ),
                            ),
                          ),
                          Container(
                            height: 90,
                            padding: EdgeInsets.only(bottom: 12),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SvgPicture.asset(
                                'assets/bluebus.svg',
                                ) 
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Spacer(flex: 3),
          //status text at bottom
          Row(
            children: [
              Spacer(),
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: getColor(context, ColorType.opposite),
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(width: 10,),
              Text(
                loadpoint.message,
                style: TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                ),
              ),
              Spacer(),
            ],
          ),
          Spacer(flex: 1),
        ],
      ),
    );
  }
}
