import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// iOS Map widget
class MapWidget extends StatelessWidget {
  final LatLng initialCenter;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final void Function(GoogleMapController)? onMapCreated;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;

  const MapWidget({
    super.key,
    required this.initialCenter,
    required this.polylines,
    required this.markers,
    this.onMapCreated,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = true,
    this.mapToolbarEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: 15.0,
      ),
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: LatLng(42.217530, -83.809124), // Southern and Westernmost point
          northeast: LatLng(42.328602, -83.685307), // Northern and Easternmost point
        )
      ),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      mapToolbarEnabled: mapToolbarEnabled,
      polylines: polylines,
      markers: markers,
    );
  }
} 

// written by efe akinci, adapted from M-Bus
// we need a separate one so it animates the bus (which is only default on iOS)
class AndroidMap extends StatefulWidget {
  final LatLng initialCenter;
  final Set<Polyline> polylines;
  final Set<Marker> dynamicMarkers;
  final Set<Marker> staticMarkers;
  final void Function(GoogleMapController)? onMapCreated;
  final bool myLocationButtonEnabled;
  AndroidMap(
      {super.key,
      required this.initialCenter,
      required this.dynamicMarkers,
      required this.staticMarkers,
      this.onMapCreated,
      this.polylines = const {},
      this.myLocationButtonEnabled = false,});

  @override
  _AndroidMapState createState() => _AndroidMapState();
}

class _AndroidMapState extends State<AndroidMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Set<Marker> curMarkers = {};
  Map<MarkerId, Marker> _startMarkers = {};
  Map<MarkerId, Marker> _targetMarkers = {};
  bool _hasPending = false;
  Set<Marker>? _pendingDynamicMarkers;
  int? mapId;
  GoogleMapController? _gController;
  bool? _lastIsDark;
  static const int _targetFps = 15;
  late final Duration _minFrameGap =
      Duration(milliseconds: (1000 / _targetFps).floor());
  Duration _lastPaint = Duration.zero;

  double _shortestAngleDelta(double fromDeg, double toDeg) {
    double delta = (toDeg - fromDeg + 540) % 360 - 180;
    return delta;
  }

  void _startAnimation(Set<Marker> newDynamicMarkers) {
    _targetMarkers = {
      for (final m in newDynamicMarkers) m.markerId: m,
    };

    if (_startMarkers.isEmpty) {
      curMarkers = newDynamicMarkers;
      _startMarkers = Map.of(_targetMarkers);
      setState(() {});
      return;
    }

    _lastPaint = Duration.zero;
    _controller.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    curved.addListener(() {
      final now = _controller.lastElapsedDuration ?? Duration.zero;
      if (now - _lastPaint < _minFrameGap) return;
      _lastPaint = now;
      _paintInterpolated(curved.value);
    });
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _paintInterpolated(1.0);
        _onAnimationDone();
      }
    });
  }

  void _paintInterpolated(double t) {
    final interpolated = <Marker>{};
    for (final entry in _targetMarkers.entries) {
      final MarkerId id = entry.key;
      final Marker target = entry.value;
      final Marker start = _startMarkers[id] ?? target;
      final double lat = start.position.latitude +
          (target.position.latitude - start.position.latitude) * t;
      final double lng =
          _lerpLng(start.position.longitude, target.position.longitude, t);
      final double rot = start.rotation +
          _shortestAngleDelta(start.rotation, target.rotation) * t;
      interpolated.add(Marker(
        markerId: id,
        anchor: target.anchor,
        onTap: target.onTap,
        icon: target.icon,
        position: LatLng(lat, lng),
        rotation: rot,
        zIndex: target.zIndex,
        consumeTapEvents: target.consumeTapEvents,
      ));
    }
    setState(() {
      curMarkers = interpolated;
    });
  }

  void _onAnimationDone() {
    _startMarkers = Map.of(_targetMarkers);
    if (_hasPending && _pendingDynamicMarkers != null) {
      _hasPending = false;
      final pending = _pendingDynamicMarkers!;
      _pendingDynamicMarkers = null;
      _lastPaint = Duration.zero;
      _startAnimation(pending);
    }
  }

  double _lerpLng(double startLng, double endLng, double t) {
    double s = startLng;
    double e = endLng;
    double delta = e - s;
    if (delta > 180) s += 360;
    if (delta < -180) e += 360;
    double value = s + (e - s) * t;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AndroidMap oldWidget) {
    final incoming = widget.dynamicMarkers;
    if (_controller.isAnimating) {
      _hasPending = true;
      _pendingDynamicMarkers = incoming;
    } else {
      _startMarkers = {
        for (final m in oldWidget.dynamicMarkers) m.markerId: m,
      };
      _startAnimation(incoming);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      compassEnabled: false,
      myLocationEnabled: widget.myLocationButtonEnabled,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: LatLng(42.217530, -83.809124), // Southern and Westernmost point
          northeast: LatLng(42.328602, -83.685307), // Northern and Easternmost point
        )
      ),
      markers: curMarkers.union(widget.staticMarkers),
      initialCameraPosition: CameraPosition(
        target: widget.initialCenter,
        zoom: 15.0,
      ),
      polylines: widget.polylines,
      onMapCreated: widget.onMapCreated,
    );
  }
}