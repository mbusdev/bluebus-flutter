import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bluebus/constants.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/models/bus_route_line.dart';
import 'package:bluebus/services/route_color_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MapImageService {
      // Custom marker icons
  BitmapDescriptor? busIcon;
  // BitmapDescriptor? stopIcon;
  BitmapDescriptor stopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  BitmapDescriptor? favStopIcon;
  final Map<String, Uint8List> _routeBusIcons = {};

  Future<void> loadCustomMarkers(Function() onCompleted) async {
    try {
      // Load and resize stop icon
      final stopBytes = await rootBundle.load('assets/bus_stop.png');
      final stopCodec = await ui.instantiateImageCodec(
        stopBytes.buffer.asUint8List(),
        targetWidth: 70,
        targetHeight: 70,
      );
      final stopFrame = await stopCodec.getNextFrame();
      final stopData = await stopFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      stopIcon = BitmapDescriptor.fromBytes(stopData!.buffer.asUint8List());

      // Load favorite stop icon
      try {
        final favBytes = await rootBundle.load('assets/fav_stop.png');
        final favCodec = await ui.instantiateImageCodec(
          favBytes.buffer.asUint8List(),
          targetWidth: 70,
          targetHeight: 70,
        );
        final favFrame = await favCodec.getNextFrame();
        final favData = await favFrame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (favData != null) {
          favStopIcon = BitmapDescriptor.fromBytes(
            favData.buffer.asUint8List(),
          );
        }
      } catch (_) {
        favStopIcon = null;
      }

      // Load route specific bus icons
      await _loadRouteSpecificBusIcons();

      // Refresh markers with new icons

      // TODO: Run some sort of callback

      onCompleted();
      
      // if (mounted) {
      //   // TODO: Regenerate static and bus markers here too
      // }
    } catch (e) {
      // Fallback to default markers if custom loading fails
      // stopIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueAzure,
      // );
    }
  }

  // BitmapDescriptor getIconForBus(Bus bus) {
  //   if (_routeBusIcons.containsKey(bus.routeId)) {
  //     return _routeBusIcons[bus.routeId]!;
  //   } else if (busIcon != null) {
  //     return busIcon!;
  //   } else {
  //     final routeColor = bus.routeColor ?? RouteColorService.getRouteColor(bus.routeId);
  //     return BitmapDescriptor.defaultMarkerWithHue(
  //       _colorToHue(routeColor),
  //     );
  //   }
  // }

  Future<void> _loadRouteSpecificBusIcons() async {

    try {
      if (!RouteColorService.isInitialized) {
        await RouteColorService.initialize();
      }

      // Check if we need to sqe cached assets based on version
      final shouldRefreshAssets = await _shouldRefreshCachedAssets();

      final routeIds = RouteColorService.definedRouteIds;

      for (final routeId in routeIds) {
        // debugPrint("Loading bus icons for route ${routeId}");
        // Try to load from cache first if not forcing refresh
        if (!shouldRefreshAssets) {
          // debugPrint("    Loading cached icon...");
          final cachedIcon = await _loadCachedBusIcon(routeId);
          if (cachedIcon != null) {
            _routeBusIcons[routeId] = cachedIcon;
            continue;
          }
        }

        // Load from backend if cache miss or forcing refresh
        final imageUrl = RouteColorService.getRouteImageUrl(routeId);
        if (imageUrl != null) {
          // debugPrint("    Cache missing, loading from backend...");
          await _loadRouteBusIcon(routeId, imageUrl);
        } else {
          // _setFallbackBusIcon(routeId);
        }
      }
    } catch (e) {
      // Fallback to default bus icon
      // debugPrint("Error (around line 122): " + e.toString());
      // busIcon = BitmapDescriptor.defaultMarkerWithHue(
      //   BitmapDescriptor.hueYellow,
      // );
    }
  }

    // Check if cached assets need to be refreshed based on backend version
  Future<bool> _shouldRefreshCachedAssets() async {
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

  Future<int> getFrontEndImageVer() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int counter = prefs.getInt('imageVer') ?? 0;

    // if null, save the default value
    if (prefs.getInt('imageVer') == null) {
      await prefs.setInt('imageVer', counter);
    }

    return counter;
  }

  Future<void> setFrontEndImageVer(int a) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('imageVer', a);
  }

    // Get minimum supported version from backend
  Future<String?> _getBackendImageVersion() async {
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
  Future<Uint8List?> _loadCachedBusIcon(String routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBytes = prefs.getString('new_bus_icon_$routeId');
      
      if (cachedBytes != null) {
        // debugPrint("    Cache check--bytes IS NOT null");
        final bytes = base64.decode(cachedBytes);
        return bytes;
      }
      // debugPrint("    Cache check--bytes IS null");
    } catch (e) {
      // debugPrint("    Cache error: ${e.toString()}");
      // Return null on error
    }
    return null;
  }

  // Save bus icon to cache
  Future<void> _cacheBusIcon(String routeId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = base64.encode(bytes);
      await prefs.setString('new_bus_icon_$routeId', base64String);
    } catch (e) {
      // Ignore cache save errors
    }
  }


  // THIS IS WHAT WE NEED
  Future<void> _loadRouteBusIcon(String routeId, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        _routeBusIcons[routeId] = imageBytes;
        _cacheBusIcon(routeId, imageBytes); // Save it in the cache for later!

        // // Adjust bus icon size here
        // try {
        //   final codec = await ui.instantiateImageCodec(
        //     imageBytes,
        //     targetWidth: 125,
        //     targetHeight: 125,
        //   );
        //   final frame = await codec.getNextFrame();
        //   final data = await frame.image.toByteData(
        //     format: ui.ImageByteFormat.png,
        //   );

        //   if (data != null) {
        //     final processedBytes = data.buffer.asUint8List();
        //     _routeBusIcons[routeId] = BitmapDescriptor.fromBytes(
        //       processedBytes,
        //     );

        //     // Cache the processed icon for future use
        //     await _cacheBusIcon(routeId, processedBytes);
        //   } else {
        //     _setFallbackBusIcon(routeId);
        //   }
        // } catch (codecError) {
        //   _setFallbackBusIcon(routeId);
        // }
      } else {
        // Set fallback icon for this route
        // _setFallbackBusIcon(routeId);
      }
    } catch (e) {
      // Set fallback icon for this route
      // _setFallbackBusIcon(routeId);
    }
  }

  // // Set a fallback bus icon for a route
  // void _setFallbackBusIcon(String routeId) {
  //   try {
  //     final routeColor = RouteColorService.getRouteColor(routeId);
  //     _routeBusIcons[routeId] = BitmapDescriptor.defaultMarkerWithHue(
  //       _colorToHue(routeColor),
  //     );
  //   } catch (e) {
  //     // error handling
  //   }
  // }

  void ensureCachedBusIconsForRoutes(List<BusRouteLine> routes) {
    for (final r in routes) {

      // Load bus icon for this route if not already loaded
      if (!_routeBusIcons.containsKey(r.routeId)) {
        final imageUrl = RouteColorService.getRouteImageUrl(r.routeId);
        if (imageUrl != null) {
          _loadRouteBusIcon(r.routeId, imageUrl);
        }
      }
    }

    // debugPrint("BUS ICONS: We now have ${_routeBusIcons.length} icons cached");
    
  }

  bool busIconExists(String routeId) {
    return _routeBusIcons.containsKey(routeId);
  }

  Uint8List getBusIconBytes(String routeId) {
    return _routeBusIcons[routeId]!;
  }

  // Convert a Color to a BitmapDescriptor hue value
  double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

}