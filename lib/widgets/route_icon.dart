import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';

class RouteIcon extends StatelessWidget {
  const RouteIcon({super.key, 
    required this.rtid,
    required this.size,
    required this.fontSize,
  });

  factory RouteIcon.sized(String rtid, int size, {Key? key}) {
    return RouteIcon(
      key: key,
      rtid: rtid,
      size: size,
      fontSize: (size / 2).floor(),
    );
  }

  factory RouteIcon.small(String rtid, {Key? key}) {
    return RouteIcon.sized(rtid, 35, key: key);
  }

  factory RouteIcon.medium(String rtid, {Key? key}) {
    return RouteIcon.sized(rtid, 40, key: key);
  }

  factory RouteIcon.large(String rtid, {Key? key}) {
    return RouteIcon.sized(rtid, 60, key: key);
  }

  final String rtid;
  final int size;
  final int fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.toDouble(),
      height: size.toDouble(),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RouteColorService.getRouteColor(rtid),
      ),
      alignment: Alignment.center,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(1.0)),
        child: Text(
          rtid,
          style: TextStyle(
            color: RouteColorService.getContrastingColor(rtid),
            fontSize: fontSize.toDouble(),
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
