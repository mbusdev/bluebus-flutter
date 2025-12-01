import 'dart:async';
import 'dart:convert';

import 'package:bluebus/constants.dart';
import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const _updateInterval = Duration(minutes: 1);
const remindersKey = "bus_reminder";

/// Key for registration token as known by backend
/// i.e. what to call /reminders with
const serverTokenKey = "server_registration_token";

class IncomingBusReminderService {
  static bool _started = false;
  static late SharedPreferencesWithCache userPrefs;
  // static late Timer _timer;
  // static Map<({String stpid, String rtid}), int> prevArrivalInfo = {};

  static Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    userPrefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {remindersKey, serverTokenKey},
      ),
    );
    if (_serverToken() != null) {
      // notifications were used before, complete setup
      // TODO: make sure this won't lead to constant permission requests
      // for someone who has denied notification
      await _completeSetup();
    }
    // _timer = Timer.periodic(_updateInterval, (_) async {
    //   if (kDebugMode) {
    //     debugPrint("Doing reminder processing...");
    //   }
    //   try {
    //     final reminders = getActiveReminders();
    //     final stops = reminders.map((x) => x.stpid).toSet();
    //     final incomingBusResults = Stream.fromFutures(
    //       stops.map((stop) async {
    //         return (stop, await fetchStopData(stop));
    //       }),
    //     );

    //     final Map<({String stpid, String rtid}), int> currArrivalInfo = {};
    //     await for (final (stop, (buses, _)) in incomingBusResults) {
    //       for (final bus in buses) {
    //         final event = (rtid: bus.id, stpid: stop);
    //         final prediction = bus.prediction == 'DUE'
    //             ? 0
    //             : int.parse(bus.prediction);
    //         if (currArrivalInfo[event] == null ||
    //             currArrivalInfo[event]! > prediction) {
    //           currArrivalInfo[event] = prediction;
    //         }
    //       }
    //     }

    //     for (final entry in currArrivalInfo.entries) {
    //       if (entry.value <= reminderThreshold &&
    //           (!prevArrivalInfo.containsKey(entry.key) ||
    //               prevArrivalInfo[entry.key]! > reminderThreshold)) {
    //         NotificationService.sendLocalNotification(
    //           "Bus Alert",
    //           "${entry.key.rtid} will be at ${entry.key.stpid}",
    //         );
    //         await Future.delayed(_notificationWaitTime);
    //       }
    //     }
    //   } catch (e) {
    //     print("Reminder processing failed with: $e");
    //   }
    //   if (kDebugMode) {
    //     print("Reminder processing finished");
    //   }
    // });
    // });
  }

  static Future<void> _completeSetup() async {
    NotificationService.setTokenChangeCallback(_onTokenChange);
    await NotificationService.requestPermission();
    String? currToken = NotificationService.token();
    if (currToken != null) {}
    if (currToken != null && currToken != _serverToken()) {
      await _onTokenChange(currToken);
    }
  }

  static String? _serverToken() {
    return userPrefs.getString(serverTokenKey);
  }

  static Future<void> _onTokenChange(String token) async {
    final serverToken = _serverToken();
    if (serverToken != null) {
      if (!await _swapToken(oldTok: _serverToken()!, newTok: token)) {
        print("swap token FAILED");
      }
    }
    userPrefs.setString(serverTokenKey, token);
  }

  static Future<void> addReminder(String stpid, String rtid) async {
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _setReminder(token: token, rtid: rtid, stpid: stpid) && kDebugMode) {
      debugPrint("setting reminder failed");
    }
    assert(!rtid.contains("|"));
    var activeReminders = userPrefs.getStringList(remindersKey);
    activeReminders ??= [];
    activeReminders.add("$rtid|$stpid");
    if (kDebugMode) {
      debugPrint("reminders is now $activeReminders");
    }
    await userPrefs.setStringList(remindersKey, activeReminders);
  }

  static Future<void> removeReminder(String stpid, String rtid) async {
    // TODO: avoid excessive setup work
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _unsetReminder(token: token, stpid: stpid, rtid: rtid)) {
      debugPrint("unsetting reminder failed");
    }

    assert(!rtid.contains("|"));
    final activeReminders = userPrefs.getStringList(remindersKey);
    if (activeReminders == null) {
      return;
    }
    if (activeReminders.contains("$rtid|$stpid")) {
      activeReminders.remove("$rtid|$stpid");
      if (kDebugMode) {
        debugPrint("reminders is now $activeReminders");
      }
      await userPrefs.setStringList(remindersKey, activeReminders);
    }
  }

  static bool isActiveReminder(String stpid, String rtid) {
    final activeReminders = getActiveReminders();
    return activeReminders.contains((stpid: stpid, rtid: rtid));
  }

  static Set<({String stpid, String rtid})> getActiveReminders() {
    var activeReminders = userPrefs.getStringList(remindersKey);
    activeReminders ??= [];
    return activeReminders
        .map((x) => x.split('|'))
        .map((parts) => (stpid: parts[1], rtid: parts[0]))
        .toSet();
  }
}

Future<bool> _setReminder({
  required String token,
  required String rtid,
  required String stpid,
}) async {
  final res = await http.post(
    Uri.parse('$BACKEND_URL/setReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'token': token,
      'event': {'rtid': rtid, 'stpid': stpid},
    }),
  );
  return res.statusCode == 200;
}

Future<bool> _unsetReminder({
  required String token,
  required String rtid,
  required String stpid,
}) async {
  final res = await http.post(
    Uri.parse('$BACKEND_URL/unsetReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'token': token,
      'event': {'rtid': rtid, 'stpid': stpid},
    }),
  );
  return res.statusCode == 200;
}

Future<bool> _swapToken({
  required String oldTok,
  required String newTok,
}) async {
  final res = await http.post(
    Uri.parse('$BACKEND_URL/swapToken'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'oldTok': oldTok, 'newTok': newTok}),
  );
  return res.statusCode == 200;
}



// Future<List<({String rtid, String stpid})>?> _fetchReminders(
//   String token,
// ) async {
//   final res = await http.post(
//     Uri.parse('$BACKEND_URL/reminder'),
//     headers: {'Content-Type': 'application/json'},
//     body: jsonEncode({'token': token}),
//   );
//   if (res.statusCode != 200) return null;
//   return jsonDecode(res.body).reminders;
// }
