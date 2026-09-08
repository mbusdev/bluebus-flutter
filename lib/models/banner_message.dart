import 'package:google_maps_flutter/google_maps_flutter.dart';

class BannerMessage {
  final String shortTitle;
  final String url;
  final LatLng location;

  // Whether the banner should actually be shown. False by default: it's only
  // true if the hardcoded banner is switched on below, or one came back from
  // the server. _loadAllData() switches it back off for a title-less banner.
  // Mutable, so this class can't be const.
  bool isActive;

  BannerMessage({
    required this.shortTitle,
    required this.url,
    required this.location,
    this.isActive = false,
  });

  factory BannerMessage.fromJson(Map<String, dynamic> json) {
    return BannerMessage(
      shortTitle: json['shortTitle'] ?? '',
      url: json['linkUrl'] ?? '',
      location: LatLng(
        json['latitude']?.toDouble() ?? 0,
        json['longitude']?.toDouble() ?? 0,
      ),
      isActive: true, // TODO: Check this!
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
  );
  static final BannerMessage none = BannerMessage(
    shortTitle: '',
    url: '',
    location: LatLng(0,0),
    isActive: false
  );
}
