import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../constants.dart';

final double ANIMATION_VELOCITY_DECAY = 0.90;

class ZoomTimestamp { // Timestamp that records zoom as well
  late int timestamp;
  late double zoom;

  ZoomTimestamp(CameraPosition position) {
    zoom = position.zoom;
    timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  bool operator ==(Object lhs) {
    return lhs is ZoomTimestamp && (lhs.zoom == this.zoom);
  }

  @override
  int get hashCode => Object.hash(timestamp, zoom);

  @override
  String toString() {
    return "ZoomTimestamp: zoom: $zoom, time: $timestamp";
  }
}

class ZoomInertiaAnimation {
  late AnimationController _controller;
  GoogleMapController? mapController;
  double zoomVelocity = -0.2;
  List<ZoomTimestamp> zoomTimestamps = []; // TODO: Cap this at e.g. 100 elements so it doesn't get huge
  bool isAnimating = false;
  LatLng? focalPoint;
  double currentZoom = 0;

  bool shouldIgnoreCameraMotion = false; // Whether to ignore "ghost" camera movements created by the animation
                                         // See comment in resetAnimation() for more info on why this is here
  

  void animationTick() {
    if (!isAnimating) return;
    if (focalPoint == null) return;

    debugPrint("        Animation tick!");
    
    // This runs on every frame
    // mapController?.moveCamera(CameraUpdate.zoomBy(zoomVelocity * 1000 / 60));
    currentZoom = currentZoom + (zoomVelocity * 1000 / 60);

    if (currentZoom > 20) { // Avoid zooming in too much
      resetAnimation();
      return;
    }

    mapController?.moveCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: focalPoint ?? LatLng(0,0),
        zoom: currentZoom
      )
    ));
    zoomVelocity = zoomVelocity * ANIMATION_VELOCITY_DECAY;

    if (zoomVelocity.abs() < 0.001) {
      debugPrint("Velocity is too slow! Stopping animation");
      resetAnimation();
    }
  }

  ZoomInertiaAnimation(TickerProviderStateMixin mixin) {
    debugPrint("Initializing animation controller");
    _controller = AnimationController(
      vsync: mixin,
      duration: const Duration(seconds: 2)
    );

    // _controller.addListener(animationTick); // This runs every frame
    _controller.addStatusListener((status) {
      // if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      //   debugPrint("Animation complete!");
      //   resetAnimation();
      // }
    });
  }

  void resetAnimation() {
    debugPrint("Resetting animation");
    if (!isAnimating) return; // Don't double-reset the animation
    isAnimating = false;
    shouldIgnoreCameraMotion = true;

    _controller.removeListener(animationTick); // To avoid extra map shfiting when the animation resets
    _controller.stop();
    zoomTimestamps = [];
    _controller.reset();

    Future.delayed(Duration(milliseconds: 70), () {
      shouldIgnoreCameraMotion = false;
      // onCameraMove() runs from an event queue, so once _controller.stop() is called
      // onCameraMove a few extra times. This 50-millisecond delay prevents onCameraMove
      // from mistaking these movements for user input

    });

  }

  void startAnimation() {
    // zoomVelocity = -0.2;
    zoomVelocity = getLastZoomVelocity();
    debugPrint("Animation started! Initial zoom velocity is $zoomVelocity");
    if (zoomVelocity == 0.0 && zoomTimestamps.length > 3) {
      debugPrint("    Recent zoom: ${zoomTimestamps[zoomTimestamps.length - 1]}");
      debugPrint("    2nd recent:  ${zoomTimestamps[zoomTimestamps.length - 2]}");
      debugPrint("    3rd recent:  ${zoomTimestamps[zoomTimestamps.length - 3]}");
    } else if (zoomVelocity == 0) {
      debugPrint("    zoomTimestamps has length ${zoomTimestamps.length}");
    }
    if (zoomVelocity == 0) return;
    
    isAnimating = true;
    debugPrint("Got startAnimation() call");

    _controller.addListener(animationTick);

    _controller.forward(from: 0.0).whenComplete(() {
      resetAnimation();
    });
  }

  void dispose() {
    _controller.dispose();
  }

  void assignMapController(GoogleMapController controller) {
    debugPrint("Assigning map controller");
    this.mapController = controller;
  }

  double getZoomVelocityBetweenPoints(lIndex, rIndex) {
    if (zoomTimestamps[rIndex].timestamp == zoomTimestamps[lIndex].timestamp) {
      debugPrint("Returning 0 to avoid dividing by 0");
      return 0; // Avoid dividing by 0
    }
    return (zoomTimestamps[rIndex].zoom - zoomTimestamps[lIndex].zoom) / (zoomTimestamps[rIndex].timestamp - zoomTimestamps[lIndex].timestamp).toDouble();
  }

  double getLastZoomVelocity() {
    // if (zoomTimestamps.length < 3) return 0;
    // int lastIndex = zoomTimestamps.length - 1;

    // double pointA = getZoomVelocityBetweenPoints(lastIndex - 1, lastIndex);
    // double pointB = getZoomVelocityBetweenPoints(lastIndex - 2, lastIndex);

    // debugPrint("Getting last zoom velocity");
    // debugPrint("    Velocity at point A: $pointA");
    // debugPrint("    Velocity at point B: $pointB");

    // // Gets the zoom velocity from the last three points
    // return (pointA + pointB) / 2.0;

    if (zoomTimestamps.length < 2) return 0;
    int lastIndex = zoomTimestamps.length - 1;
    double lastZoomVelocity = getZoomVelocityBetweenPoints(lastIndex - 1, lastIndex);

    if (lastZoomVelocity < -0.2) return -0.2;
    if (lastZoomVelocity > 0.2) return 0.2;
    return lastZoomVelocity;

  }

  void onCameraMove(CameraPosition position) {

    if (shouldIgnoreCameraMotion) return;

    if (isAnimating) {
      // debugPrint("Automated: Got onCameraMove call");
      return;
    } else {
      // debugPrint("Manual: Got onCameraMove call");
    }
    

    ZoomTimestamp zStamp = ZoomTimestamp(position);

    if (zoomTimestamps.isEmpty || zStamp != zoomTimestamps[zoomTimestamps.length - 1]) {
      // debugPrint("        New zoom timestamp! $zStamp");
      zoomTimestamps.add(zStamp);

      // lastLat = position.target.latitude;
      // lastLon = position.target.longitude;
      focalPoint = position.target;
      currentZoom = position.zoom;

      double lastZoomVelocity = getLastZoomVelocity();
      // debugPrint("Last zoom velocity: $lastZoomVelocity");
    }

  }

  void onCameraIdle() {
    debugPrint("Camera idle!");
    startAnimation();
  }
}

// iOS Map widget
class MapWidget extends StatelessWidget {
  final LatLng initialCenter;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final String darkMapStyle;
  final String lightMapStyle;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(CameraPosition)? onCameraMove;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  
  const MapWidget({
    super.key,
    required this.initialCenter,
    required this.polylines,
    required this.markers,
    required this.darkMapStyle,
    required this.lightMapStyle,
    this.onMapCreated,
    this.onCameraMove,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = true,
    this.mapToolbarEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
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
      style: isDarkMode(context) ? darkMapStyle : lightMapStyle
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
  final String darkMapStyle;
  final String lightMapStyle;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(CameraPosition)? onCameraMove;
  final bool myLocationButtonEnabled;
  AndroidMap(
      {super.key,
      required this.initialCenter,
      required this.dynamicMarkers,
      required this.staticMarkers,
      required this.darkMapStyle,
      required this.lightMapStyle,
      this.onMapCreated,
      this.onCameraMove,
      this.polylines = const {},
      this.myLocationButtonEnabled = false,});

  @override
  _AndroidMapState createState() => _AndroidMapState();
}

class _AndroidMapState extends State<AndroidMap>
    // with SingleTickerProviderStateMixin {
    with TickerProviderStateMixin {
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

  late ZoomInertiaAnimation zoomAnimation;

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
    debugPrint("Initting state");

    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    zoomAnimation = ZoomInertiaAnimation(this);
    // zoomAnimation.init(this);

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
    return Stack(
      children: [
        GoogleMap(
          compassEnabled: false,
          myLocationEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,

          mapType: MapType.normal,
          buildingsEnabled: false, // Disable 3D buildings for performance
          indoorViewEnabled: false, // Disabled for performance
          trafficEnabled: false, // Disabled for performance
          
          cameraTargetBounds: CameraTargetBounds(
            LatLngBounds(
              southwest: LatLng(42.217530, -83.809124), // Southern and Westernmost point
              northeast: LatLng(42.328602, -83.668917), // Northern and Easternmost point
            )
          ),
          markers: curMarkers.union(widget.staticMarkers),
          initialCameraPosition: CameraPosition(
            target: widget.initialCenter,
            zoom: 15.0,
          ),
          polylines: widget.polylines,
          onMapCreated: (controller) {
            widget.onMapCreated!(controller);
            zoomAnimation.assignMapController(controller);
          },
          onCameraMove: (CameraPosition position) {
            widget.onCameraMove!(position);
            zoomAnimation.onCameraMove(position);
          },
          onCameraIdle: () {
            zoomAnimation.onCameraIdle();
          },
          style: isDarkMode(context) ? widget.darkMapStyle : widget.lightMapStyle,

        ),

        // Positioned(
        //   top: 500,
        //   left: 50,
        //   child: MaterialButton(
        //   onPressed: zoomAnimation.startAnimation,
        //     child: Text("Animate!"),
        //   )
        // )
        
    
    ]);
  
  }
}