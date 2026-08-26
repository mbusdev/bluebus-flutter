import 'package:bluebus/models/floorplan.dart';
import 'package:flutter/material.dart';

/// Everything about how a floorplan *looks*, kept in one place so the design
/// can be retuned without touching the drawing code.

/// How much of a floorplan we draw, chosen from the current camera zoom.
///
/// The levels are ordered: each one draws everything the previous one did,
/// plus more detail.
enum FloorplanDetailLevel {
  /// Too far out for the building to be meaningful -- draw nothing.
  hidden,

  /// A single filled blob showing the building's footprint.
  outline,

  /// The full plan: base footprint, walls and rooms.
  full,

  /// The full plan plus room labels and POI icons.
  labeled,
}

/// Zoom at which the building footprint starts being drawn at all.
const double FLOORPLAN_OUTLINE_ZOOM = 14.0;

/// Zoom at which the plain footprint is swapped for the detailed floorplan.
const double FLOORPLAN_DETAIL_ZOOM = 17.5;

/// Zoom at which room labels and POI icons appear on top of the floorplan.
const double FLOORPLAN_LABEL_ZOOM = 18.75;

/// Picks the detail level for a camera zoom.
FloorplanDetailLevel floorplanDetailLevelForZoom(double zoom) {
  if (zoom >= FLOORPLAN_LABEL_ZOOM) return FloorplanDetailLevel.labeled;
  if (zoom >= FLOORPLAN_DETAIL_ZOOM) return FloorplanDetailLevel.full;
  if (zoom >= FLOORPLAN_OUTLINE_ZOOM) return FloorplanDetailLevel.outline;
  return FloorplanDetailLevel.hidden;
}

// --- Colors -----------------------------------------------------------------

/// Fill of the zoomed-out building footprint.
const Color FLOORPLAN_FAR_OUTLINE_FILL = Color(0xFFFFE594);

/// Stroke of the zoomed-out building footprint.
const Color FLOORPLAN_FAR_OUTLINE_STROKE = Color(0xFFCDBC8A);

/// Fill of the footprint once the detailed plan is showing. Everything else is
/// drawn on top of this.
const Color FLOORPLAN_BASE_FILL = Color(0xFFEAE9F4);

/// The one dark blue used for every stroke in the detailed plan: the footprint,
/// the walls and the room outlines.
const Color FLOORPLAN_STROKE = Color(0xFF133E65);

/// Fill used for room types we don't have a specific color for.
const Color FLOORPLAN_DEFAULT_ROOM_FILL = Color(0xFF90B8D5);

/// Room fill per room type. Types missing from this map fall back to
/// [FLOORPLAN_DEFAULT_ROOM_FILL].
const Map<String, Color> FLOORPLAN_ROOM_FILLS = {
  FloorplanTypes.room: Color(0xFF90B8D5),
  FloorplanTypes.elevator: Color(0xFF5E96B3),
  FloorplanTypes.stairway: Color(0xFF5E96B3),
  FloorplanTypes.escalator: Color(0xFF5E96B3),
  FloorplanTypes.inaccessible: Color(0xFF133E65),
  FloorplanTypes.information: Color(0xFF72BD9B),
  FloorplanTypes.food: Color(0xFF72BD9B),
  FloorplanTypes.femaleBathroom: Color(0xFF8973B9),
  FloorplanTypes.maleBathroom: Color(0xFF8973B9),
  FloorplanTypes.neutralBathroom: Color(0xFF8973B9),
};

Color floorplanRoomFill(String roomType) =>
    FLOORPLAN_ROOM_FILLS[roomType] ?? FLOORPLAN_DEFAULT_ROOM_FILL;

// --- Stroke widths ----------------------------------------------------------

const int FLOORPLAN_FAR_OUTLINE_STROKE_WIDTH = 2;
const int FLOORPLAN_BASE_STROKE_WIDTH = 3;
const int FLOORPLAN_WALL_STROKE_WIDTH = 2;
const int FLOORPLAN_ROOM_STROKE_WIDTH = 1;

// --- Draw order -------------------------------------------------------------
//
// Google Maps shares one z-index space across polygons and polylines (markers
// always sit above both), so these values order the whole detailed plan.
// Walls are drawn last, over the room fills, so no wall is ever painted over.

const int FLOORPLAN_Z_BASE = 0;
const int FLOORPLAN_Z_ROOMS = 1;
const int FLOORPLAN_Z_WALLS = 2;
const int FLOORPLAN_Z_MARKERS = 1000;

// --- Labels -----------------------------------------------------------------

/// Font size of a room label, in logical pixels.
const double FLOORPLAN_LABEL_FONT_SIZE = 11.0;

const Color FLOORPLAN_LABEL_COLOR = Color(0xFF133E65);

/// Halo drawn behind label text so it stays readable over any room fill.
const Color FLOORPLAN_LABEL_HALO_COLOR = Color(0xCCFFFFFF);
const double FLOORPLAN_LABEL_HALO_WIDTH = 3.0;

/// Resolution multiplier used when rasterizing label text, so labels stay
/// crisp on high density screens.
const double FLOORPLAN_LABEL_PIXEL_RATIO = 3.0;

/// POI types that get a text label drawn at their position.
const Set<String> FLOORPLAN_LABELED_POI_TYPES = {
  FloorplanTypes.room,
  FloorplanTypes.food,
};

// --- Icons ------------------------------------------------------------------

/// Rendered size of a POI icon, in logical pixels.
const double FLOORPLAN_ICON_SIZE = 22.0;

/// Gap between a POI icon and the label underneath it, in logical pixels.
const double FLOORPLAN_ICON_LABEL_GAP = 2.0;

/// Icon asset per POI type. Types missing from this map get no icon.
const Map<String, String> FLOORPLAN_POI_ICONS = {
  FloorplanTypes.elevator: 'assets/floorplans/icons/elevator.png',
  FloorplanTypes.stairway: 'assets/floorplans/icons/stairs.png',
  FloorplanTypes.escalator: 'assets/floorplans/icons/escalator.png',
  FloorplanTypes.information: 'assets/floorplans/icons/info.png',
  FloorplanTypes.food: 'assets/floorplans/icons/food.png',
  FloorplanTypes.femaleBathroom: 'assets/floorplans/icons/bathroomF.png',
  FloorplanTypes.maleBathroom: 'assets/floorplans/icons/bathroomM.png',
  FloorplanTypes.neutralBathroom: 'assets/floorplans/icons/bathroomN.png',
};
