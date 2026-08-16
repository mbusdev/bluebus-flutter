import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

const STOP_ICON_WIDTH = 65;
const STOP_ICON_HEIGHT = 65;

const FANCY_STOP_ICON_XHEADROOM = 20;
const FANCY_STOP_ICON_YHEADROOM = 20;

const FANCY_STOP_ICON_MARGIN = 10;
const FANCY_STOP_ICON_SMALLMARGIN = 5;

const ROW_ICON_SIZE = (STOP_ICON_HEIGHT - FANCY_STOP_ICON_SMALLMARGIN + FANCY_STOP_ICON_YHEADROOM * 2) / 2;

const FANCY_STOP_ICON_WIDTH = FANCY_STOP_ICON_XHEADROOM + STOP_ICON_WIDTH + FANCY_STOP_ICON_MARGIN + (ROW_ICON_SIZE + FANCY_STOP_ICON_SMALLMARGIN) * 3; // Add enough space for the stop icon, margins, and 3 route icons

const FANCY_STOP_ICON_HEIGHT = 65 + FANCY_STOP_ICON_XHEADROOM * 2;

class MapImageService {
  // Route specific bus icons
  static Map<String, BitmapDescriptor> _routeBusIcons = {};
  static BitmapDescriptor? _busIcon;

  static Map<String, BitmapDescriptor> _fancyStopIconsCache = {}; // Cache for fancy stop icons. Key format is "[rotation],[buscode],[buscode],...", such as "274,NW,CS,CX,BB"

  // TODO: Maybe make this manage stop icons too?


  static BitmapDescriptor stopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  static BitmapDescriptor rideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  static BitmapDescriptor favStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  static BitmapDescriptor favRideStopIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );

  static ui.Image? _stopIconImage;
  static ui.Image? _rideStopIconImage;
  static ui.Image? _favStopIconImage;
  static ui.Image? _favRideStopIconImage;

  static ByteData? _stopIconBytes;
  static ByteData? _rideStopIconBytes;
  static ByteData? _favStopIconBytes;
  static ByteData? _favRideStopIconBytes;

  static bool _stopIconsInitialized = false;

  static Future<int> getFrontEndImageVer() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int counter = prefs.getInt('imageVer') ?? 0;

    // if null, save the default value
    if (prefs.getInt('imageVer') == null) {
      await prefs.setInt('imageVer', counter);
    }

    return counter;
  }

  static Future<void> setFrontEndImageVer(int a) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('imageVer', a);
  }

  // Check if cached assets need to be refreshed based on backend version
  static Future<bool> _shouldRefreshCachedAssets() async {
    int frontEndVer;
    frontEndVer = await getFrontEndImageVer();

    try {
      final backendImageVersion = await _getBackendImageVersion();
      if (backendImageVersion == null) {
        return true; // if you can't reach the server give up
      }
      if (int.parse(backendImageVersion) == frontEndVer) {
        return false;
      } else {
        await setFrontEndImageVer(int.parse(backendImageVersion));
        return true;
      }
    } catch (e) {
      // On error, assume refresh needed
      return true;
    }
  }

  // Get minimum supported version from backend
  static Future<String?> _getBackendImageVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${BACKEND_URL}/getStartupInfo'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['bus_image_version'] as String?;
      }
    } catch (e) {
      // Return null on error - will trigger refresh
    }
    return null;
  }

  // Load cached bus icon from SharedPreferences
  static Future<BitmapDescriptor?> _loadCachedBusIcon(String routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBytes = prefs.getString('bus_icon_$routeId');
      if (cachedBytes != null) {
        final bytes = base64.decode(cachedBytes);
        return BitmapDescriptor.fromBytes(bytes);
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  // Save bus icon to cache
  static Future<void> _cacheBusIcon(String routeId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = base64.encode(bytes);
      await prefs.setString('bus_icon_$routeId', base64String);
    } catch (e) {
      // Ignore cache save errors
    }
  }

  // Set a fallback bus icon for a route
  static void _setFallbackBusIcon(String routeId) {
    try {
      final routeColor = RouteColorService.getRouteColor(routeId);
      _routeBusIcons[routeId] = BitmapDescriptor.defaultMarkerWithHue(
        colorToHue(routeColor),
      );
    } catch (e) {
      // error handling
    }
  }

  // Load a specific route's bus icon
  static Future<void> _loadRouteBusIcon(String routeId, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;

        // Adjust bus icon size here
        try {
          final codec = await ui.instantiateImageCodec(
            imageBytes,
            targetWidth: 125,
            targetHeight: 125,
          );
          final frame = await codec.getNextFrame();
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );

          if (data != null) {
            final processedBytes = data.buffer.asUint8List();
            _routeBusIcons[routeId] = BitmapDescriptor.fromBytes(
              processedBytes,
            );

            // Cache the processed icon for future use
            await _cacheBusIcon(routeId, processedBytes);
          } else {
            _setFallbackBusIcon(routeId);
          }
        } catch (codecError) {
          _setFallbackBusIcon(routeId);
        }
      } else {
        // Set fallback icon for this route
        _setFallbackBusIcon(routeId);
      }
    } catch (e) {
      // Set fallback icon for this route
      _setFallbackBusIcon(routeId);
    }
  }

  // Load route specific bus icons from the backend
  static Future<void> _loadRouteSpecificBusIcons() async {
    try {
      if (!RouteColorService.isInitialized) {
        await RouteColorService.initialize();
      }

      // Check if we need to update cached assets based on version
      final shouldRefreshAssets = await _shouldRefreshCachedAssets();

      final routeIds = RouteColorService.definedRouteIds;

      for (final routeId in routeIds) {
        // Try to load from cache first if not forcing refresh
        if (!shouldRefreshAssets) {
          final cachedIcon = await _loadCachedBusIcon(routeId);
          if (cachedIcon != null) {
            _routeBusIcons[routeId] = cachedIcon;
            continue;
          }
        }

        // Load from backend if cache miss or forcing refresh
        final imageUrl = RouteColorService.getRouteImageUrl(routeId);
        if (imageUrl != null) {
          await _loadRouteBusIcon(routeId, imageUrl);
        } else {
          _setFallbackBusIcon(routeId);
        }
      }
    } catch (e) {
      // Fallback to default bus icon
      _busIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueYellow,
      );
    }
  }

  static Future<void> _loadStopIcons() async {
    try {
      _stopIconBytes = await rootBundle.load('assets/busStop.png');
      _rideStopIconBytes = await rootBundle.load('assets/busStopRide.png');
      _favStopIconBytes = await rootBundle.load('assets/favbusStop.png');
      _favRideStopIconBytes = await rootBundle.load('assets/favbusStopRide.png');

      _stopIconImage = await _decode(_stopIconBytes!);
      _rideStopIconImage = await _decode(_rideStopIconBytes!);
      _favStopIconImage = await _decode(_favStopIconBytes!);
      _favRideStopIconImage = await _decode(_favRideStopIconBytes!);

      // Load stop icons
      stopIcon = await MapImageService.resizeImage(_stopIconBytes!);
      rideStopIcon = await MapImageService.resizeImage(_rideStopIconBytes!);
      favStopIcon = await MapImageService.resizeImage(_favStopIconBytes!,);
      favRideStopIcon = await MapImageService.resizeImage(_favRideStopIconBytes!);

      _stopIconsInitialized = true;

    } catch (e) {
      debugPrint("Error! $e");
      // Fallback to default markers if custom loading fails
      // These are now set as initial values
    }
  }

  static Future<BitmapDescriptor?> ensureRouteIconIsLoaded(
    String routeId,
  ) async {
    if (_routeBusIcons.containsKey(routeId))
      return _routeBusIcons[routeId]; // Already in cache, no need to do anything else

    final prefs = await SharedPreferences.getInstance();
    final cachedBytes = prefs.getString('bus_icon_$routeId');
    if (cachedBytes != null) {
      final bytes = base64.decode(cachedBytes);
      _routeBusIcons[routeId] = BitmapDescriptor.fromBytes(bytes);
      return _routeBusIcons[routeId]; // Icon is already cached!
    }

    // Load bus icon for this route if not already loaded
    // if (!_routeBusIcons.containsKey(routeId)) {
    final imageUrl = RouteColorService.getRouteImageUrl(routeId);
    if (imageUrl != null) {
      await _loadRouteBusIcon(routeId, imageUrl);
      return _routeBusIcons[routeId];
    }
    // }
  }

  // Check if a route has specific bus icon loaded
  bool hasRouteBusIcon(String routeId) {
    return _routeBusIcons.containsKey(routeId);
  }

  // Get the number of route bus icons loaded
  int get loadedBusIconCount => _routeBusIcons.length;

  // Refresh route specific bus icons
  static void refreshRouteBusIcons() {
    _routeBusIcons.clear();
    _loadRouteSpecificBusIcons();
  }
// NEXT STEPS TODO: Figure out how to create a Canvas that's the right size, add the stop image to it, and then add extra stuff (e.g. rectangles) just to show we can
  static Future<BitmapDescriptor> resizeImage(ByteData image) async {
    // Load and resize stop icon
    final stopBytes = image;
    final stopCodec = await ui.instantiateImageCodec(
      stopBytes.buffer.asUint8List(),
      targetWidth: 65,
      targetHeight: 65,
    );
    final stopFrame = await stopCodec.getNextFrame();
    final stopData = await stopFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(stopData!.buffer.asUint8List());
  }

  static bool isBusIconAvailable(Bus bus) {
    return _routeBusIcons.containsKey(bus.routeId) ||
        _busIcon !=
            null; // TODO: Should this include a check for _busIcon like in getBusIcon()?
  }

  static BitmapDescriptor getBusIcon(Bus bus) {
    final routeColor =
        bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);

    if (_routeBusIcons.containsKey(bus.routeId)) {
      return _routeBusIcons[bus.routeId]!;
    } else if (_busIcon != null) {
      return _busIcon!;
    } else {
      debugPrint(
        "WARN: getBusIcon found no icon currently loaded, returning defaultMarkerWithHue",
      );
      return BitmapDescriptor.defaultMarkerWithHue(colorToHue(routeColor));
    }
  }

  static Future<ui.Image> _decode(ByteData data) async {
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void drawRouteIconOntoCanvas(Canvas canvas, int x, int y, int width, int height, String routeId, bool isRide) {
    final paint = Paint()
      ..color = RouteColorService.getRouteColor(routeId)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      text: TextSpan(
        text: routeId,
        style: TextStyle(
          fontSize: width / 2,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          fontFamily: 'Urbanist'
        )
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr
    )..layout(minWidth: 0, maxWidth: width.toDouble());
    
    if (isRide) {
      double rideIconHeight = height.toDouble() * 0.75;
      double marginTop = (height - rideIconHeight) / 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x.toDouble(), y.toDouble() + marginTop, width.toDouble(), rideIconHeight), 
        Radius.circular(rideIconHeight / 2),
      );
      canvas.drawRRect(rrect, paint);
    } else {
      canvas.drawCircle(Offset(x + width / 2, y + height / 2), width / 2, paint);
    }
    textPainter.paint(canvas, Offset(x + width / 2 - (textPainter.width / 2), y + height / 2 - (textPainter.height / 2)));
    // textPainter.paint(canvas, Offset(0,0));
  }

  static void drawRotatedImage(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double angleRadians,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRadians);
    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2), // shift so `center` is the pivot
      Paint(),
    );
    canvas.restore();
  }

  static double degreesToRadians(double degrees) => degrees * math.pi / 180;

// NEXT STEPS TODO: Pass in a hardcoded list of bus stops and get the circles rendering nicely (as well as the arrow for the bus stop). Also get anchoring and zoom level switching working properly
//
// *** Cache NOT based on stop ID, but based on the routes in the given list (to make our cache more resilient/flexible). Sort the list alphabetically each time
  static Future<BitmapDescriptor> getFancyStopIcon(String stopId, bool isFavorite, bool isRide, double rotation, List<String> routesServed) async { // TODO: Pass in a list of bus route codes here later

    // String cacheKey = rotation.round().toString() + "," + routesServed.join(",");
    // String cacheKey = routesServed.join(","); // Temporary, for testing
    String cacheKey = "${stopId}_$isFavorite";


    if (_fancyStopIconsCache.containsKey(cacheKey)) {
      return _fancyStopIconsCache[cacheKey]!;
    }

    // TODO: Add the bus stop icon type (favorite, nonfavorite, TheRide favorite, etc)

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // debugPrint("Generating icon for ${routesServed.join(",")}");

    // int total_width = STOP_ICON_WIDTH * 2 + STOP_ICON_WIDTH;
    // int total_height = STOP_ICON_HEIGHT;

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    

    try {
      if (!_stopIconsInitialized) {
        // debugPrint("Stop icons not initialized, loading...");
        await _loadStopIcons();
      }

      ui.Image? targetImage = isFavorite ?
          (isRide ? _favRideStopIconImage : _favStopIconImage) :
          (isRide ? _rideStopIconImage : _stopIconImage);

      drawRotatedImage(
        canvas,
        targetImage!,
        Offset(
          FANCY_STOP_ICON_XHEADROOM.toDouble() + (STOP_ICON_WIDTH.toDouble() / 2),
          FANCY_STOP_ICON_YHEADROOM.toDouble() + (STOP_ICON_HEIGHT.toDouble() / 2)),
        degreesToRadians(rotation)
      );

      // canvas.drawImage(_stopIconImage!, Offset(FANCY_STOP_ICON_XHEADROOM.toDouble(), FANCY_STOP_ICON_YHEADROOM.toDouble()), Paint()); // 1 pixel to 1 canvas unit. I'm treating canvas units as pixels here
    } catch (err) {}

    // canvas.drawRect(Rect.fromLTWH(STOP_ICON_WIDTH.toDouble(), 0, (FANCY_STOP_ICON_WIDTH - STOP_ICON_WIDTH).toDouble(), STOP_ICON_HEIGHT.toDouble()), paint);

    int maxRouteIconsPerRow = ((FANCY_STOP_ICON_WIDTH - FANCY_STOP_ICON_XHEADROOM - STOP_ICON_WIDTH - FANCY_STOP_ICON_MARGIN) / (ROW_ICON_SIZE + FANCY_STOP_ICON_SMALLMARGIN)).floor().toInt();

    int xDrawPos = STOP_ICON_WIDTH + FANCY_STOP_ICON_XHEADROOM + FANCY_STOP_ICON_MARGIN;
    int yDrawPos = 0;

    if (routesServed.length <= maxRouteIconsPerRow) {
      yDrawPos = (FANCY_STOP_ICON_HEIGHT / 2 - ROW_ICON_SIZE / 2).floor();
    }



    for (int i = 0; i < routesServed.length; i++) {
      if (xDrawPos + ROW_ICON_SIZE > FANCY_STOP_ICON_WIDTH) {
        // If the route icon is going to get clipped, wrap to the next row
        yDrawPos += ROW_ICON_SIZE.toInt() + FANCY_STOP_ICON_SMALLMARGIN;
        xDrawPos = FANCY_STOP_ICON_XHEADROOM + STOP_ICON_WIDTH + FANCY_STOP_ICON_MARGIN;
      }
      
      String routeId = routesServed[i];
      drawRouteIconOntoCanvas(
        canvas,
        xDrawPos, // x
        yDrawPos, // y
        ROW_ICON_SIZE.toInt(), // width
        ROW_ICON_SIZE.toInt(), // height
        routeId,
        isRide);

      xDrawPos += ROW_ICON_SIZE.toInt() + FANCY_STOP_ICON_SMALLMARGIN;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(FANCY_STOP_ICON_WIDTH.toInt(), FANCY_STOP_ICON_HEIGHT);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    BitmapDescriptor output = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _fancyStopIconsCache[cacheKey] = output;
    return output;
  }

  static Offset getFancyStopIconOffset() {
    double offsetX = (STOP_ICON_WIDTH.toDouble() / 2 + FANCY_STOP_ICON_XHEADROOM) / FANCY_STOP_ICON_WIDTH.toDouble();
    double offsetY = 0.5;
    // debugPrint("Offset X: $offsetX, Y: $offsetY");
    return Offset(offsetX, offsetY);
    // return Offset(0.5, 0.5);
  }

  static Future<void> loadData() async {
    await _loadRouteSpecificBusIcons();

    await _loadStopIcons();
  }
}
