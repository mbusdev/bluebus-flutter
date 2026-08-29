import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:bluebus/models/floorplan.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Converts a floorplan's plan-pixel coordinates into real world lat/lng.
///
/// A floor carries two georeferencing POIs (`waypoint1` and `waypoint2`) whose
/// real world positions we know. Two matched point pairs are exactly enough to
/// pin down a *similarity transform* -- uniform scale, rotation and translation
/// -- which is all a flat floorplan needs. Solving for rotation too (rather
/// than assuming the plan is drawn north-up) means buildings that were drawn at
/// an angle line up without any extra data.
///
/// The math is done in a local equirectangular space where
/// `x = longitude * cos(referenceLatitude)` and `y = latitude`, so that one
/// unit of x and one unit of y cover the same real world distance. Over a
/// single building the distortion from this is far below drawing precision.
class FloorplanProjection {
  /// Scale/rotation, stored as the complex number `_scaleCos + i * _scaleSin`.
  final double _scaleCos;
  final double _scaleSin;

  /// Translation in the local equirectangular space.
  final double _translateX;
  final double _translateY;

  final double _cosReferenceLatitude;

  const FloorplanProjection._(
    this._scaleCos,
    this._scaleSin,
    this._translateX,
    this._translateY,
    this._cosReferenceLatitude,
  );

  /// Solves for the transform that maps [pixelA] onto [worldA] and [pixelB]
  /// onto [worldB].
  ///
  /// Returns null if the two pixel points coincide, which would leave the
  /// scale and rotation undetermined.
  static FloorplanProjection? fromControlPoints({
    required Offset pixelA,
    required LatLng worldA,
    required Offset pixelB,
    required LatLng worldB,
  }) {
    final double referenceLatitude = (worldA.latitude + worldB.latitude) / 2;
    final double cosReferenceLatitude = math.cos(referenceLatitude * math.pi / 180);

    // Plan pixels grow downward while latitude grows upward, so flip y.
    final double planAx = pixelA.dx;
    final double planAy = -pixelA.dy;
    final double planBx = pixelB.dx;
    final double planBy = -pixelB.dy;

    final double worldAx = worldA.longitude * cosReferenceLatitude;
    final double worldAy = worldA.latitude;
    final double worldBx = worldB.longitude * cosReferenceLatitude;
    final double worldBy = worldB.latitude;

    final double planDx = planBx - planAx;
    final double planDy = planBy - planAy;
    final double worldDx = worldBx - worldAx;
    final double worldDy = worldBy - worldAy;

    final double planLengthSquared = planDx * planDx + planDy * planDy;
    if (planLengthSquared == 0) return null;

    // Complex division (worldDelta / planDelta) gives scale and rotation at once.
    final double scaleCos = (worldDx * planDx + worldDy * planDy) / planLengthSquared;
    final double scaleSin = (worldDy * planDx - worldDx * planDy) / planLengthSquared;

    final double translateX = worldAx - (scaleCos * planAx - scaleSin * planAy);
    final double translateY = worldAy - (scaleSin * planAx + scaleCos * planAy);

    return FloorplanProjection._(
      scaleCos,
      scaleSin,
      translateX,
      translateY,
      cosReferenceLatitude,
    );
  }

  /// Builds the projection for [floor] from its two waypoint POIs.
  ///
  /// Returns null if the floor is missing either waypoint, in which case we
  /// have no way to place it on the map and it should not be drawn.
  static FloorplanProjection? forFloor(
    FloorplanFloor floor, {
    required LatLng waypoint1,
    required LatLng waypoint2,
  }) {
    final FloorplanPoi? poi1 = floor.findPoiByType(FloorplanTypes.waypoint1);
    final FloorplanPoi? poi2 = floor.findPoiByType(FloorplanTypes.waypoint2);
    if (poi1 == null || poi2 == null) return null;

    return fromControlPoints(
      pixelA: poi1.position,
      worldA: waypoint1,
      pixelB: poi2.position,
      worldB: waypoint2,
    );
  }

  /// Projects a single plan-pixel point into real world coordinates.
  LatLng toLatLng(Offset planPoint) {
    final double planX = planPoint.dx;
    final double planY = -planPoint.dy;

    final double worldX = _scaleCos * planX - _scaleSin * planY + _translateX;
    final double worldY = _scaleSin * planX + _scaleCos * planY + _translateY;

    return LatLng(worldY, worldX / _cosReferenceLatitude);
  }

  /// Projects a whole polygon or polyline.
  List<LatLng> toLatLngList(List<Offset> planPoints) =>
      planPoints.map(toLatLng).toList();
}
