import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BannerMessage {
  final String shortTitle;
  final String url;
  LatLng? location;
  final DateTime showTime;
  final DateTime hideTime;

  // Whether the banner should actually be shown. False by default: it's only
  // true if the hardcoded banner is switched on below, or one came back from
  // the server. _loadAllData() switches it back off for a title-less banner.
  // Mutable, so this class can't be const.
  bool isActive;

  BannerMessage({
    required this.shortTitle,
    required this.url,
    this.location,
    required this.showTime,
    required this.hideTime,
    this.isActive = false,
  });

  factory BannerMessage.fromJson(Map<String, dynamic> json) {
    DateTime showTime = DateTime.parse("2000-01-01 17:14:00Z");
    DateTime endTime = DateTime.parse("2035-01-01 17:14:00Z");
    try {
      showTime = DateTime.parse(json['showTime'] ?? "2000-01-01 17:14:00Z");
    } catch (err) {}
    try {
      endTime = DateTime.parse(json['showTime'] ?? "2035-01-01 17:14:00Z");
    } catch (err) {}

    bool locationExists = (json['latitude']?.toDouble() ?? 0) != 0 && (json['longitude']?.toDouble() ?? 0) != 0; // Make sure lat/lon is neither missing nor zero

    return BannerMessage(
      shortTitle: json['shortTitle'] ?? '',
      url: json['linkUrl'] ?? 'https://www.maizebus.com',
      location: locationExists ? LatLng(
        json['latitude']?.toDouble() ?? 0,
        json['longitude']?.toDouble() ?? 0,
      ) : null,
      isActive: true,
      showTime: showTime,
      hideTime: endTime
    );
  }

  // Hardcoded until the backend serves 'banner_message' in /getStartupInfo.
  // Once it does, swap this for BannerMessage.fromJson(data['banner_message'])
  // in _getStartupData() and delete this. (Sep 4 2026)
  static final BannerMessage hardcoded = BannerMessage(
    shortTitle: 'JOIN',
    url: 'https://www.maizebus.com/',
    location: LatLng(42.278653, -83.728791),
    isActive: true, // flip to false to switch the banner off without deleting it
    showTime: DateTime.parse("2026-03-16 00:00:00Z"),
    hideTime: DateTime.parse("2030-03-24 00:00:00Z")
  );
  static final BannerMessage none = BannerMessage(
    shortTitle: '',
    url: '',
    location: LatLng(0,0),
    isActive: false,
    showTime: DateTime.parse("2026-03-16 00:00:00Z"),
    hideTime: DateTime.parse("2030-03-24 00:00:00Z")
  );
}
