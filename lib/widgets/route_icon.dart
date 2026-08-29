import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';

/// lets you check if a bus is the ride (checks if id is numeric)
bool isRide(String? s) {
  if (s != null && int.tryParse(s) != null) {
    // busID is numeric, so it's a ride bus
    return true;
  }
  return false;
}

class RouteIcon extends StatelessWidget {
  const RouteIcon({
    super.key,
    required this.rtid,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  /// Match aspect ratio of medium but with a custom size
  /// The other set sizes have different aspect ratios!
  factory RouteIcon.sized(
    String rtid,
    double size, {
    Key? key,
  }) {
    return RouteIcon(
      key: key,
      rtid: rtid,
      width: isRide(rtid) ? size * 1.125 : size,
      height: isRide(rtid) ? size * 0.875 : size,
      fontSize: (size / 2).floor(),
    );
  }

  factory RouteIcon.small(
    String rtid, {
    Key? key,
  }) {
    return RouteIcon(
      rtid: rtid,
      key: key,
      width: isRide(rtid) ? 40 : 35,
      height: isRide(rtid) ? 30 : 35,
      fontSize: 17,
    );
  }

  factory RouteIcon.smallWithLargerFont(
    String rtid, {
    Key? key,
  }) {
    return RouteIcon(
      rtid: rtid,
      key: key,
      width: isRide(rtid) ? 40 : 35,
      height: isRide(rtid) ? 30 : 35,
      fontSize: 18,
    );
  }

  factory RouteIcon.medium(
    String rtid, {
    Key? key,
  }) {
    return RouteIcon.sized(rtid, 40, key: key);  // 45 x 35 for theride
  }

  factory RouteIcon.large(
    String rtid, {
    Key? key,
  }) {
    return RouteIcon(
      rtid: rtid,
      width: isRide(rtid) ? 78 : 60,
      height: isRide(rtid) ? 55 : 60,
      fontSize: 30,
      key: key,
    );
  }

  final String rtid;
  final double width, height;
  final int fontSize;

  @override
  Widget build(BuildContext context) {
    final bgColor = RouteColorService.getRouteColor(rtid);
    final fgColor = RouteColorService.getContrastingColor(rtid);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      alignment: Alignment.center,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(1.0)),
        child: Text(
          rtid,
          style: TextStyle(
            color: fgColor,
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
