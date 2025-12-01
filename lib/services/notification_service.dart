
import 'package:bluebus/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool listeningForFcmUpdates = false;
  static String? _registrationToken;
  static Function(String)? _tokenChangeCallback;

  /// This only starts the local notification plugin along with some other basic setup,
  /// requestPermissions() should be called later to complete setup.
  ///
  /// e.g. call it asap if notifications were previously used, otherwise wait for
  /// the user to trigger a feature that requires notifications
  static Future<void> initPlugin() async {
    await Firebase.initializeApp(
      name: "[DEFAULT]",
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // prepare local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('appicon_no_bg');
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    final initialized = await _localNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: null,
      onDidReceiveBackgroundNotificationResponse: null,
    );
    if ((initialized == null || !initialized) && kDebugMode) {
      debugPrint("Failed to initialize notifications!");
    }

    // Push Notifications
    // channel used by push notifications (to make sure it shows up)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      "high_importance_channel",
      "Push Notifications",
      description: "Used for reminders!",
      importance: Importance.max,
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> requestPermission() async {
    final notificationSettings = await FirebaseMessaging.instance
        .requestPermission();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true);
    final apnsToken = await FirebaseMessaging.instance
        .getAPNSToken(); // ensure it exists for iOS to work
      print("apns token:");
      print(apnsToken);
    _registrationToken = await FirebaseMessaging.instance.getToken();
    print(_registrationToken);

    if (!listeningForFcmUpdates) {
      listeningForFcmUpdates = true;
      FirebaseMessaging.instance.onTokenRefresh
          .listen((fcmToken) {
            _registrationToken = fcmToken;
            _tokenChangeCallback?.call(fcmToken);
          })
          .onError((err) {
            if (kDebugMode) {
              debugPrint("fcm token refresh error: $err");
            }
          });
    }
  }

  static void setTokenChangeCallback(Function(String) callback) {
    _tokenChangeCallback = callback;
  }

  /// This can only not be null if `requestPermission()` is called
  static String? token() {
    return _registrationToken;
  }

  // if (Platform.isIOS /*|| Platform.isMacOS*/ ) {
  //   await _localNotificationsPlugin
  //       .resolvePlatformSpecificImplementation<
  //         IOSFlutterLocalNotificationsPlugin
  //       >()
  //       ?.requestPermissions(alert: true, badge: true, sound: true);
  //   await _localNotificationsPlugin
  //       .resolvePlatformSpecificImplementation<
  //         MacOSFlutterLocalNotificationsPlugin
  //       >()
  //       ?.requestPermissions(alert: true, badge: true, sound: true);
  // } else if (Platform.isAndroid) {
  //   final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  //       _localNotificationsPlugin
  //           .resolvePlatformSpecificImplementation<
  //             AndroidFlutterLocalNotificationsPlugin
  //           >();

  //   await androidImplementation?.requestNotificationsPermission();
  // }
  // }

  // static Future<void> sendTestPushNotification() async {
  //   await FirebaseMessaging.instance.getAPNSToken();
  //   final registrationToken = await FirebaseMessaging.instance.getToken();
  //   await http.post(
  //     Uri.parse('$BACKEND_URL/notifyMeLater'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'token': registrationToken}),
  //   );
  // }

  // static Future<void> sendLocalNotification(String? title, String? body) async {
  //   const AndroidNotificationDetails androidNotificationDetails =
  //       AndroidNotificationDetails(
  //         'your channel id',
  //         'your channel name',
  //         channelDescription: 'your channel description',
  //         importance: Importance.defaultImportance,
  //         priority: Priority.defaultPriority,
  //         ticker: 'ticker',
  //       );
  //   const NotificationDetails notificationDetails = NotificationDetails(
  //     android: androidNotificationDetails,
  //   );
  //   await _localNotificationsPlugin.show(
  //     _id++,
  //     title,
  //     body,
  //     notificationDetails,
  //     //payload: 'item x',
  //   );
  // }
}

// int _id = 0;
