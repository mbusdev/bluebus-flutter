import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initPlugin() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('appicon_no_bg');
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    final initialized = await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: null,
      onDidReceiveBackgroundNotificationResponse: null,
    );
    if ((initialized == null || !initialized) && kDebugMode) {
      debugPrint("Failed to initialize notifications!");
    }
  }

  static Future<void> requestPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  static Future<void> sendNotification() async {
    
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await _notificationsPlugin.show(
        0, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');

  }
}
