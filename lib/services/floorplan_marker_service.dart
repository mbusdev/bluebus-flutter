import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluebus/services/floorplan_style.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds and caches the bitmaps used by the floorplan layer's markers: POI
/// icons loaded from assets, and room labels rasterized from text.
///
/// Both caches are static and keyed by content, so the same label or icon is
/// only ever built once no matter how many floors or buildings ask for it.
class FloorplanMarkerService {
  static final Map<String, BitmapDescriptor> _iconCache = {};
  static final Map<String, BitmapDescriptor> _labelCache = {};

  /// The icon for a POI type, or null if that type doesn't have one.
  static Future<BitmapDescriptor?> icon(String poiType) async {
    final cached = _iconCache[poiType];
    if (cached != null) return cached;

    final String? assetPath = FLOORPLAN_POI_ICONS[poiType];
    if (assetPath == null) return null;

    try {
      final BitmapDescriptor descriptor = await BitmapDescriptor.asset(
        ImageConfiguration.empty,
        assetPath,
        width: FLOORPLAN_ICON_SIZE,
        height: FLOORPLAN_ICON_SIZE,
      );
      _iconCache[poiType] = descriptor;
      return descriptor;
    } catch (err) {
      debugPrint('FloorplanMarkerService: could not load $assetPath ($err)');
      return null;
    }
  }

  /// Rasterizes [text] into a marker bitmap.
  ///
  /// Markers are positioned by their center, so to push a label off center the
  /// bitmap is grown asymmetrically: padding added above the text moves the
  /// bitmap's center up, which pushes the text down relative to the anchor
  /// point. [belowIcon] uses that to drop the label clear of a POI icon drawn
  /// at the same position.
  static Future<BitmapDescriptor> label(
    String text, {
    bool belowIcon = false,
  }) async {
    final String cacheKey = '$text|$belowIcon';
    final cached = _labelCache[cacheKey];
    if (cached != null) return cached;

    const double scale = FLOORPLAN_LABEL_PIXEL_RATIO;
    final double haloWidth = FLOORPLAN_LABEL_HALO_WIDTH * scale;

    // The same text painted twice: a thick stroke for the halo, then the fill.
    TextPainter paintedText(Paint? stroke) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: FLOORPLAN_LABEL_FONT_SIZE * scale,
          fontWeight: FontWeight.w600,
          fontFamily: 'Urbanist',
          color: stroke == null ? FLOORPLAN_LABEL_COLOR : null,
          foreground: stroke,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final TextPainter halo = paintedText(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloWidth
        ..strokeJoin = StrokeJoin.round
        ..color = FLOORPLAN_LABEL_HALO_COLOR,
    );
    final TextPainter fill = paintedText(null);

    // Enough margin that the halo stroke isn't clipped at the bitmap edges.
    final double margin = haloWidth;

    // How far below the anchor point the text should end up.
    final double dropBelowAnchor = belowIcon
        ? (FLOORPLAN_ICON_SIZE / 2 + FLOORPLAN_ICON_LABEL_GAP) * scale +
              fill.height / 2
        : 0.0;

    final double width = fill.width + margin * 2;
    final double height = fill.height + margin * 2 + dropBelowAnchor * 2;
    final Offset textOrigin = Offset(margin, margin + dropBelowAnchor * 2);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    halo.paint(canvas, textOrigin);
    fill.paint(canvas, textOrigin);

    final ui.Image image = await recorder.endRecording().toImage(
      width.ceil(),
      height.ceil(),
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    final BitmapDescriptor descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: scale,
    );
    _labelCache[cacheKey] = descriptor;
    return descriptor;
  }
}
