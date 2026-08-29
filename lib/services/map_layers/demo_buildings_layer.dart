// ---------------------------------------------------------------------------
// DEMO ONLY -- REMOVE AFTER THE DEMO.
//
// We only have real floorplan data for one building (the Duderstadt), but the
// demo wants the map to look like it knows about a whole campus. This layer
// fakes that by drawing hand-traced building footprints from a CSV, styled to
// match the zoomed-out footprint the real FloorplansLayer draws. They never
// gain any detail when you zoom in -- they're outlines and nothing more.
//
// To rip it out, in this order:
//   1. delete this file
//   2. delete assets/floorplans/demoPolygons.csv
//   3. delete the three lines tagged `// DEMO BUILDINGS` in
//      lib/screens/map_screen.dart  (grep for the tag)
//
// Nothing else in the app references any of it.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:bluebus/services/floorplan_style.dart';
import 'package:bluebus/widgets/composite_map_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws static building footprints parsed from a CSV of WKT polygons.
///
/// Loads itself on construction, so wiring it up is just adding it to the
/// map's layer list. Follows the same zoom cutoff as the real floorplans
/// ([FLOORPLAN_OUTLINE_ZOOM]) so the fake buildings appear and disappear
/// alongside the real one.
class DemoBuildingsLayer extends CompositeMapLayer {
  static const String _asset = 'assets/floorplans/demoPolygons.csv';

  @override
  bool isVisible = true;
  @override
  Set<Polygon> polygons = const {};
  @override
  Set<Polyline> polylines = const {};
  @override
  Set<Marker> markers = const {};
  @override
  Function() onUpdate = () {};

  /// Every footprint from the CSV, built once at load.
  Set<Polygon> _footprints = const {};

  /// Matches the map's initial camera, since [onCameraMove] only fires once
  /// the user actually moves.
  FloorplanDetailLevel _detailLevel = floorplanDetailLevelForZoom(
    INITIAL_MAP_ZOOM,
  );

  Future<void>? _loading;

  DemoBuildingsLayer() {
    load();
  }

  /// Parses the CSV and builds the footprints. Only happens once, however many
  /// times this is called.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(_asset);
    } catch (err) {
      debugPrint('DemoBuildingsLayer: failed to load $_asset ($err)');
      return;
    }

    _footprints = _buildFootprints(raw);
    _applyDetailLevel();
    if (isVisible) onUpdate();
  }

  @override
  void onCameraMove(CameraPosition oldPosition, CameraPosition newPosition) {
    final FloorplanDetailLevel level = floorplanDetailLevelForZoom(
      newPosition.zoom,
    );
    if (level == _detailLevel) return;

    _detailLevel = level;
    _applyDetailLevel();
    if (isVisible) onUpdate();
  }

  @override
  void setOnUpdate(Function() callback) {
    onUpdate = callback;
  }

  /// These buildings have no detailed plan to swap in, so the only thing the
  /// zoom decides is whether they're drawn at all.
  void _applyDetailLevel() {
    polygons = _detailLevel == FloorplanDetailLevel.hidden
        ? const {}
        : _footprints;
  }

  // --- Parsing -------------------------------------------------------------

  /// Turns the CSV into polygons. Rows we can't make sense of are skipped
  /// rather than thrown, since a bad row should cost us one building and not
  /// the whole layer.
  static Set<Polygon> _buildFootprints(String csv) {
    final Set<Polygon> result = {};
    final List<String> lines = const LineSplitter().convert(csv);

    // Row 0 is the `WKT,name,description` header.
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final List<String> fields = _splitCsvLine(lines[i]);
      if (fields.isEmpty) continue;

      final List<LatLng> outline = _parseWktPolygon(fields[0]);
      if (outline.length < 3) {
        debugPrint('DemoBuildingsLayer: skipping unparseable row $i');
        continue;
      }

      final String name = fields.length > 1 && fields[1].trim().isNotEmpty
          ? fields[1].trim()
          : 'row$i';

      result.add(
        Polygon(
          polygonId: PolygonId('demo_building_$name'),
          points: outline,
          fillColor: FLOORPLAN_FAR_OUTLINE_FILL,
          strokeColor: FLOORPLAN_FAR_OUTLINE_STROKE,
          strokeWidth: FLOORPLAN_FAR_OUTLINE_STROKE_WIDTH,
          zIndex: FLOORPLAN_Z_BASE,
        ),
      );
    }

    return result;
  }

  /// Splits one CSV row on commas, ignoring the ones inside quotes -- which
  /// the WKT column is full of. `""` inside a quoted field is a literal quote.
  static List<String> _splitCsvLine(String line) {
    final List<String> fields = [];
    final StringBuffer field = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final String char = line[i];

      if (inQuotes) {
        if (char != '"') {
          field.write(char);
        } else if (i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }

    fields.add(field.toString());
    return fields;
  }

  /// Reads the outer ring out of a `POLYGON ((lon lat, lon lat, ...))` string.
  ///
  /// Any inner rings (holes) are ignored -- Google Maps polygons take holes
  /// separately, and none of the demo buildings have any.
  static List<LatLng> _parseWktPolygon(String wkt) {
    final int start = wkt.indexOf('((');
    if (start < 0) return const [];
    final int end = wkt.indexOf(')', start + 2);
    if (end < 0) return const [];

    final List<LatLng> points = [];
    for (final String pair in wkt.substring(start + 2, end).split(',')) {
      // WKT is x then y, so longitude comes first.
      final List<String> parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final double? lng = double.tryParse(parts[0]);
      final double? lat = double.tryParse(parts[1]);
      if (lng == null || lat == null) continue;

      points.add(LatLng(lat, lng));
    }

    return points;
  }
}
