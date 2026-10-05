import 'dart:io';
import 'dart:ui' as ui;

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/banner_message.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Draws a filled circle with `label` centered on it in white text, for use as
// a marker icon. `label` is truncated to 5 characters -- past that it starts
// running off the circle
Future<BitmapDescriptor> _drawLabeledCircleMarker(
  String label, {
  Color color = maizeBusBlue,
  double size = 80,
}) async {
  final truncated = label.length > 5 ? label.substring(0, 5) : label;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  canvas.drawCircle(center, size / 2, Paint()..color = color);

  final textPainter = TextPainter(
    text: TextSpan(
      text: truncated,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontFamily: "Urbanist",
        fontSize: 26,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size);
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

// Shows a marker for the active banner_message, if it has a location
class BannerLayer extends CompositeMapLayer {
  @override
  bool isVisible = true;

  @override
  Set<Marker> markers = {};

  @override
  Set<Polyline> polylines = {};

  @override
  Function() onUpdate = () {
    stderr.writeln("Error: onUpdate called but callback was not registered!");
  };

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  Function(BannerMessage) onTap = (_) {};

  void init(Function(BannerMessage) onTapIn) {
    onTap = onTapIn;
  }

  Future<void> setBanner(BannerMessage? banner) async {
    markers.clear();

    // No location marker to show--the banner doesn't need to have one
    if (banner == null || !banner.isActive || banner.location == null) {
      onUpdate();
      return;
    }

    // Drawn (not asset-based) placeholder icon -- a labeled circle. Swap for
    // a real design once one exists (Sep 6 2026)
    BitmapDescriptor icon;
    try {
      icon = await _drawLabeledCircleMarker(banner.shortTitle);
    } catch (e) {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }

    markers.add(
      Marker(
        markerId: const MarkerId('banner_message'),
        position: banner.location!,
        icon: icon,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
        onTap: () => onTap(banner),
      ),
    );
    onUpdate();
  }
}
