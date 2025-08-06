import 'package:flutter/material.dart';

// Manage consistent colors for each bus route
class RouteColorService {
  static const Map<String, Color> _routeColors = {
    'NW': Colors.blue,      // Northwood - Blue
    'CN': Colors.green,     // Commuter North - Green
    'CS': Colors.orange,    // Commuter South - Orange
    'NES': Colors.purple,   // North East Shuttle - Purple
    'WX': Colors.red,       // Wall street express - Red
    'WS': Colors.teal,      // Wallstreet NIB - Teal
    'CSX': Colors.indigo,   // Crisler express - Indigo
    'MX': Colors.amber,     // Medical Express - Amber
  };

  // Get the color for a specific route
  static Color getRouteColor(String routeId) {
    return _routeColors[routeId] ?? Colors.grey;
  }

  // Get all available route colors
  static Map<String, Color> get allRouteColors => Map.unmodifiable(_routeColors);

  // Get a list of route IDs that have defined colors
  static List<String> get definedRouteIds => _routeColors.keys.toList();

  // Check if a route has a defined color
  static bool hasRouteColor(String routeId) {
    return _routeColors.containsKey(routeId);
  }

  // Get a contrasting color for text/icons on the route color
  static Color getContrastingColor(String routeId) {
    final routeColor = getRouteColor(routeId);
    // Simple luminance calculation for contrast
    final luminance = routeColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
} 