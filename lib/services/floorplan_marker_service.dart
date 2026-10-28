import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluebus/services/floorplan_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';

/// Builds and caches the bitmaps used by the floorplan layer's markers: POI
/// icons loaded from assets, and room labels rasterized from text.
///
/// The caches are static and keyed by content, so the same label or icon is
/// only ever built once no matter how many floors or buildings ask for it.
class FloorplanMarkerService {
  static final Map<String, BitmapDescriptor> _iconCache = {};
  static final Map<String, BitmapDescriptor> _highlightedIconCache = {};
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

  /// Draws a 40% larger POI icon centered on a yellow circle.
  /// Returns null if the asset is missing or cannot be decoded.
  static Future<BitmapDescriptor?> highlightedIcon(String poiType) async {
    // Reuse the bitmap so repeated taps do not redraw the same icon.
    final cached = _highlightedIconCache[poiType];
    if (cached != null) return cached;

    final assetPath = FLOORPLAN_POI_ICONS[poiType];
    if (assetPath == null) return null;

    // These sizes control how large the marker appears on the map.
    const double iconSize = FLOORPLAN_ICON_SIZE;
    const double backgroundPadding = 3;
    const double markerSize = iconSize + backgroundPadding * 2;

    // Render extra pixels for sharp edges, then tell Maps their pixel ratio.
    // Increasing this value improves resolution, not the displayed size.
    const double pixelRatio = 3;
    ui.Codec? assetDecoder;
    ui.Image? originalIcon;
    ui.Picture? recordedDrawing;
    ui.Image? markerImage;

    try {
      // Decode the asset into an image that Canvas can draw.
      final assetData = await rootBundle.load(assetPath);
      assetDecoder = await ui.instantiateImageCodec(
        assetData.buffer.asUint8List(
          assetData.offsetInBytes,
          assetData.lengthInBytes,
        ),
      );
      originalIcon = (await assetDecoder.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelRatio);

      // Draw the circle first so it sits behind the icon.
      canvas.drawCircle(
        const Offset(markerSize / 2, markerSize / 2),
        markerSize / 2,
        Paint()..color = maizeBusYellow,
      );

      // Copy the entire asset into the larger, centered icon area.
      final sourceBounds = Rect.fromLTWH(
        0,
        0,
        originalIcon.width.toDouble(),
        originalIcon.height.toDouble(),
      );
      const iconBounds = Rect.fromLTWH(
        backgroundPadding,
        backgroundPadding,
        iconSize,
        iconSize,
      );
      canvas.drawImageRect(
        originalIcon,
        sourceBounds,
        iconBounds,
        Paint()..filterQuality = FilterQuality.high,
      );

      // Turn the drawing into PNG bytes that Google Maps can use as an icon.
      recordedDrawing = recorder.endRecording();
      final bitmapSize = (markerSize * pixelRatio).ceil();
      markerImage = await recordedDrawing.toImage(bitmapSize, bitmapSize);
      final pngData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngData == null) return null;

      final descriptor = BitmapDescriptor.bytes(
        pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        ),
        imagePixelRatio: pixelRatio,
      );
      _highlightedIconCache[poiType] = descriptor;
      return descriptor;
    } catch (err) {
      debugPrint(
        'FloorplanMarkerService: could not highlight $assetPath ($err)',
      );
      return null;
    } finally {
      // Release temporary graphics resources, including when generation fails.
      // The cached descriptor retains the PNG bytes it needs.
      markerImage?.dispose();
      recordedDrawing?.dispose();
      originalIcon?.dispose();
      assetDecoder?.dispose();
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
