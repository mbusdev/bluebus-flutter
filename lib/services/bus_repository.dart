import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../bluebus_api.dart';
import '../theride_api.dart';
import '../models/bus.dart';
import '../models/bus_route_line.dart';

class AppInfo {
  static String? _version;

  /// e.g. "2.0.2+8" — version and build number from pubspec.yaml
  static Future<String> version() async {
    if (_version != null) return _version!;
    final info = await PackageInfo.fromPlatform();
    _version = '${info.version}+${info.buildNumber}';
    return _version!;
  }
}

class BusRepository {
  List<BusRouteLine> _routes = [];
  static List<Bus> _buses = [];
  Timer? _busUpdateTimer;
  final Duration busUpdateInterval;

  static Future<String?> getFromCache(String key) async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/$key');
    
    if (await file.exists()) {
      return file.readAsString();
    } else {
      return null;
    }
  }

  static Future<void> writeToCache(String key, String contents) async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/$key');
    await file.writeAsString(contents);
  }

  BusRepository({this.busUpdateInterval = const Duration(seconds: 5)});

  Future<List<BusRouteLine>> fetchRoutes(Function(String route, String error) onError) async {
    // fetching the ride and bluebus routes simultaneously
    final results = await Future.wait([
      BlueBusApi.fetchRoutes(onError),
      RideAPI.fetchRoutes(onError), 
    ]);

    // merging both route lists
    _routes = results.expand((routes) => routes).toList();
    return _routes;
  }

  Future<List<BusRouteLine>> fetchRoutesFromCacheAndHTTP(Function(String route, String error) onError) async {
    String? blueBusCachedResponse = await getFromCache('bluebus-routes-cache-v${await AppInfo.version()}');
    String? theRideCachedResponse = await getFromCache('theride-routes-cache-v${await AppInfo.version()}');
    
    if (blueBusCachedResponse == null || theRideCachedResponse == null) {
      List<BusRouteLine> routes = await fetchRoutes(onError); // Wait for the HTTP download
      return routes;
    }
    
    final results = await Future.wait([
      BlueBusApi.processRoutesJson(blueBusCachedResponse, onError),
      RideAPI.processRoutesJson(theRideCachedResponse, onError), 
    ]);

    _routes = results.expand((routes) => routes).toList();
    return _routes;
  }

  Future<List<Bus>> fetchBuses() async {
    // fetching the ride and bluebus buses simultaneously
    final results = await Future.wait([
      BlueBusApi.fetchBuses(),
      RideAPI.fetchBuses(),
    ]);

    // merging both bus lists
    _buses = results.expand((buses) => buses).toList();
    return _buses;
  }

  void startBusUpdates(void Function(List<Bus>) onUpdate) {
    _busUpdateTimer?.cancel();
    _busUpdateTimer = Timer.periodic(busUpdateInterval, (_) async {
      final buses = await fetchBuses(); 
      onUpdate(buses);
    });
  }

  void stopBusUpdates() {
    _busUpdateTimer?.cancel();
  }

  void dispose() {
    stopBusUpdates();
  }

  static Bus? getBus(String busID){
    for (Bus b in _buses){
      if (b.id == busID){
        return b;
      }
    }
    return null;
  }
}