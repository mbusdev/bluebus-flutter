import 'dart:io';

import 'package:bluebus/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initPlugin() async {
    Firebase.initializeApp(
      name: "[DEFAULT]",
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // local notifications
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
    // channel used by push notifications (to make sure it shows up)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      "high_importance_channel",
      "High Importance Notifications",
      description: "Important Stuff",
      importance: Importance.max,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static bool listeningForFcmUpdates = false;

  static Future<void> requestPermission() async {
    final notificationSettings = await FirebaseMessaging.instance
        .requestPermission();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true);
    final token = await FirebaseMessaging.instance.getToken();
    print(
      "========================================\nFCM Token Is\n====================================",
    );
    print("$token");

    if (!listeningForFcmUpdates) {
      listeningForFcmUpdates = true;
      FirebaseMessaging.instance.onTokenRefresh
          .listen((fcmToken) {
            var i = 0;
            while (i < 20) {
              i++;
              print("=======================================================");
            }
            print("The fcm token is now $fcmToken");
            // TODO
          })
          .onError((err) {
            // TODO
          });
    }

    if (Platform.isIOS /*|| Platform.isMacOS*/ ) {
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

  static Future<void> sendNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'your channel id',
          'your channel name',
          channelDescription: 'your channel description',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ticker: 'ticker',
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await _notificationsPlugin.show(
      _id++,
      title,
      body,
      notificationDetails,
      //payload: 'item x',
    );
  }
}

int _id = 0;
