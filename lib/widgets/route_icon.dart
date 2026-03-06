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

enum RouteIconType { normal, outlined, normalWithWhiteBorder }

class RouteIcon extends StatelessWidget {
  const RouteIcon({
    super.key,
    required this.rtid,
    required this.size,
    required this.fontSize,
    this.type = RouteIconType.normal,
  });

  factory RouteIcon.sized(
    String rtid,
    int size, {
    Key? key,
    RouteIconType type = RouteIconType.normal,
  }) {
    return RouteIcon(
      key: key,
      rtid: rtid,
      size: size,
      fontSize: (size / 2).floor(),
      type: type,
    );
  }

  factory RouteIcon.small(
    String rtid, {
    Key? key,
    RouteIconType type = RouteIconType.normal,
  }) {
    return RouteIcon.sized(rtid, 35, key: key, type: type);
  }

  factory RouteIcon.medium(String rtid, {Key? key, RouteIconType type = RouteIconType.normal}) {
    return RouteIcon.sized(rtid, 40, key: key, type: type);
  }

  factory RouteIcon.large(String rtid, {Key? key, RouteIconType type = RouteIconType.normal}) {
    return RouteIcon.sized(rtid, 60, key: key, type: type);
  }

  final String rtid;
  final int size;
  final int fontSize;
  final RouteIconType type;

  @override
  Widget build(BuildContext context) {
    final sizeWithBorder = switch (type) {
      RouteIconType.normalWithWhiteBorder => size + 2,
      _ => size
    }.toDouble();
    final bgColor = switch (type) {
      RouteIconType.outlined => null,
      _ => RouteColorService.getRouteColor(rtid),
    };
    final fgColor = switch (type) {
      RouteIconType.outlined => RouteColorService.getRouteColor(rtid),
      _ => RouteColorService.getContrastingColor(rtid),
    };
    final border = switch (type) {
      RouteIconType.normal => null,
      RouteIconType.outlined => Border.all(color: fgColor, width: 2.0),
      // Its a weight 2 centered border in the figma but occlusion makes it look like a weight 1 outside border
      RouteIconType.normalWithWhiteBorder => Border.all(color: Color(0xFFFFFFFF), width: 1.0),
    };

    return Container( // 45, 35
      width: isRide(rtid)? sizeWithBorder * 1.125 : sizeWithBorder,
      height: isRide(rtid)? sizeWithBorder * 0.875 : sizeWithBorder,
      decoration: isRide(rtid)? 
        BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(sizeWithBorder/2),
          color: bgColor,
          border: border,
        )
        : BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: border,
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
