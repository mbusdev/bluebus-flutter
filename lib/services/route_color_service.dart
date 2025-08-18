import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

// Fetch and manage route colors and images from the backend
class RouteColorService {
  static Map<String, Color> _routeColors = {};
  static final Map<String, String> _routeImages = {};
  static final Map<String, String> _routeNames = {};
  static bool _isInitialized = false;
  static String? _lastError;

  // Fetching data from backend
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _fetchFrontendData();
      _isInitialized = true;
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      // Fallback to default colors if backend fails
      _setDefaultColors();
      _isInitialized = true; // Mark as initialized with fallback colors
    }
  }

  // Fetch all frontend data from the backend
  static Future<void> _fetchFrontendData() async {
    final response = await http.get(Uri.parse('$BACKEND_URL/getFrontendData'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _parseFrontendData(data);
    } else {
      throw Exception('Failed to fetch frontend data: ${response.statusCode}');
    }
  }

  // Parse the frontend data response
  static void _parseFrontendData(Map<String, dynamic> data) {
    _routeColors.clear();
    _routeImages.clear();
    _routeNames.clear();

    if (data.containsKey('routes')) {
      final routes = data['routes'] as List<dynamic>;
      
      for (final route in routes) {
        if (route is! Map<String, dynamic>) {
          continue;
        }
        
        final routeId = route['routeId'] as String?;
        final colorHex = route['color'] as String?;
        final imageFilename = route['image'] as String?;
        final routeName = route['name'] as String?;
        
        if (routeId == null || routeId.isEmpty) {
          continue;
        }
        
        if (colorHex == null || colorHex.isEmpty) {
          continue;
        }

        // Convert hex color to Color object
        final color = _hexToColor(colorHex);
        if (color != null) {
          _routeColors[routeId] = color;
        }

        // Store image URL
        if (imageFilename != null && imageFilename.isNotEmpty) {
          _routeImages[routeId] = '$BACKEND_URL/getVehicleImage/$routeId';
        }

        // Store route name
        if (routeName != null && routeName.isNotEmpty) {
          _routeNames[routeId] = routeName;
        }
      }
    }
  }

  // Convert hex color string to Color object
  static Color? _hexToColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor'; // Add alpha channel
      }
      
      if (hexColor.length == 8) {
        final colorValue = int.parse(hexColor, radix: 16);
        return Color(colorValue);
      }
    } catch (e) {
      // Error handling
    }
    return null;
  }

  // Fallback to default colors if backend fails
  static void _setDefaultColors() {
    _routeColors = {
      'NW': Colors.blue,
      'CN': Colors.green,
      'CS': Colors.orange,
      'NES': Colors.purple,
      'WX': Colors.red,
      'WS': Colors.teal,
      'CSX': Colors.indigo,
      'MX': Colors.amber,
    };
  }

  // Get the color for a specific route
  static Color getRouteColor(String routeId) {
    if (!_isInitialized) {
      _setDefaultColors();
    }
    return _routeColors[routeId] ?? Colors.grey;
  }

  // Get the image URL for a specific route
  static String? getRouteImageUrl(String routeId) {
    return _routeImages[routeId];
  }

  // Get the name for a specific route
  static String getRouteName(String routeId) {
    return _routeNames[routeId] ?? routeId;
  }

  // Get all available route colors
  static Map<String, Color> get allRouteColors {
    if (!_isInitialized) {
      _setDefaultColors();
    }
    return Map.unmodifiable(_routeColors);
  }

  // Get all available route images
  static Map<String, String> get allRouteImages => Map.unmodifiable(_routeImages);

  // Get all available route names
  static Map<String, String> get allRouteNames => Map.unmodifiable(_routeNames);

  // Get a list of route IDs that have defined colors
  static List<String> get definedRouteIds => _routeColors.keys.toList();

  // Check if a route has a defined color
  static bool hasRouteColor(String routeId) {
    return _routeColors.containsKey(routeId);
  }

  // Get a contrasting color for text/icons on the route color
  static Color getContrastingColor(String routeId) {
    final routeColor = getRouteColor(routeId);
    final luminance = routeColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Refresh data from backend
  static Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }
  
  // Force refresh data from backend (ignores cache)
  static Future<void> forceRefresh() async {
    _isInitialized = false;
    _routeColors.clear();
    _routeImages.clear();
    _routeNames.clear();
    await initialize();
  }

  // Check if service is initialized
  static bool get isInitialized => _isInitialized;
  
  // Check if service is using backend data (true) or fallback data (false)
  static bool get isUsingBackendData => _isInitialized && _routeColors.isNotEmpty;
  
  // Get the number of routes loaded
  static int get routeCount => _routeColors.length;
  
  // Get the last error that occurred
  static String? get lastError => _lastError;
} 
