import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MapImageService {
  // Route specific bus icons
  static Map<String, BitmapDescriptor> _routeBusIcons = {};
  static BitmapDescriptor? _busIcon;

  // TODO: Maybe make this manage stop icons too?

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
    debugPrint("      HELLO THIS IS _shouldRefreshCachedAssets()");
    int frontEndVer;
    frontEndVer = await getFrontEndImageVer();

    try {
      final backendImageVersion = await _getBackendImageVersion();
      if (backendImageVersion == null) {
        debugPrint("        Couldn't reach server! Forcing a refresh");
        return true; // if you can't reach the server give up
      }
      if (int.parse(backendImageVersion) == frontEndVer) {
        debugPrint("        Images are up-to-date, no refresh needed");
        return false;
      } else {
        debugPrint("        New images available, forcing a refresh");
        await setFrontEndImageVer(int.parse(backendImageVersion));
        return true;
      }
    } catch (e) {
      // On error, assume refresh needed
      debugPrint("_shouldRefreshCachedAssets error: ${e.toString()}");
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
      debugPrint("    getBackendImageVersion error: $e");
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
    debugPrint("      Setting fallback bus icon for route ${routeId}");
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

      debugPrint("    About to set shouldRefreshAssets variable");
      // Check if we need to update cached assets based on version
      final shouldRefreshAssets = await _shouldRefreshCachedAssets();
      debugPrint("    Finished setting shouldRefreshAssets variable");

      final routeIds = RouteColorService.definedRouteIds;

      for (final routeId in routeIds) {
        debugPrint(
          "Loading icon for route ${routeId}. Should refresh assets? $shouldRefreshAssets",
        );

        // VERY SOON TODO: Uncomment this to make sure it doesn't try to load icons that are alerady in the cache?
        // if (_routeBusIcons.containsKey(routeId)) {
        //   debugPrint("* Icon already exists, no need to fetch it again!");
        //   continue;
        // }

        // Try to load from cache first if not forcing refresh
        if (!shouldRefreshAssets) {
          debugPrint("    * Attempting to load from cache");
          final cachedIcon = await _loadCachedBusIcon(routeId);
          if (cachedIcon != null) {
            debugPrint("    * Cache hit!");
            _routeBusIcons[routeId] = cachedIcon;
            continue;
          }
        }

        debugPrint("    * Loading from backend...");

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

  // FUTURE: Maybe wrap this into a map_image_service.dart file?
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

  static Future<void> loadData() async {
    await _loadRouteSpecificBusIcons();
  }
}
