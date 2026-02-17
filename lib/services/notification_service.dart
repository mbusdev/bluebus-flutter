import 'package:bluebus/firebase_options.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _listeningForFcmUpdates = false;
  static bool _listeningForForegroundMessages = false;
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

  // Currently this function must be called even if permission is already granted,
  // as it sets up some important listeners
  static Future<void> requestPermission() async {
    // todo: add back in if needed
    //final notificationSettings = await FirebaseMessaging.instance
    //    .requestPermission();

    // notificationSettings.authorizationStatus ...
    final apnsToken = await FirebaseMessaging.instance
        .getAPNSToken(); // ensure it exists for iOS to work
    _registrationToken = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      debugPrint("apns token:");
      debugPrint(apnsToken);
      debugPrint(_registrationToken);
    }

    if (!_listeningForForegroundMessages) {
      _listeningForForegroundMessages = true;
      print("Now listening for onMessage");
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("MESSAGE!");
        debugPrint("Got a message: $message");
        if (message.notification != null) {
          NotificationService.sendLocalNotification(
            message.notification?.title,
            message.notification?.body,
            // reminderNotif,
            null,
          );
        } else {
          IncomingBusReminderService.handlePushedMessage(message.data);
        }
      });
    }

    if (!_listeningForFcmUpdates) {
      _listeningForFcmUpdates = true;
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

  static Future<void> sendLocalNotification(
    String? title,
    String? body,
    int? id,
  ) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'local-notifications',
          'Local Notifications',
          channelDescription:
              'Used when reminders trigger while the app is in the foreground',
          importance: Importance.max,
          priority: Priority.max,
          // ticker: 'ticker',
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await _localNotificationsPlugin.show(
      id ?? _id++,
      title,
      body,
      notificationDetails,
      //payload: 'item x',
    );
  }
}

const int reminderNotif = 0;
int _id = 1000;
