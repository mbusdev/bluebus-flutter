import 'dart:async';
import 'dart:convert';

import 'package:bluebus/constants.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Key for registration token as known by backend
/// i.e. what to call /reminders with
const serverTokenKey = "server_registration_token";

class IncomingBusReminderService {
  static bool _started = false;
  static late SharedPreferencesWithCache _userPrefs;

  static Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    _userPrefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {serverTokenKey},
      ),
    );
  }

  static Future<void> _completeSetup() async {
    NotificationService.setTokenChangeCallback(_onTokenChange);
    await NotificationService.requestPermission();
    String? currToken = NotificationService.token();
    if (currToken != null && currToken != _serverToken()) {
      await _onTokenChange(currToken);
    }
  }

  /// the registration token that should be used when communicating with the backend
  /// the swapping of this is handled by `_onTokenChange`
  /// make sure `_completeSetup()` has been called
  static String? _serverToken() {
    return _userPrefs.getString(serverTokenKey);
  }

  static Future<void> _onTokenChange(String token) async {
    final serverToken = _serverToken();
    if (serverToken != null) {
      if (!await _swapToken(oldTok: _serverToken()!, newTok: token) &&
          kDebugMode) {
        debugPrint("swap token failed");
      }
    }
    _userPrefs.setString(serverTokenKey, token);
  }

  static Future<void> addReminder(String stpid, String rtid, int thresh) async {
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _setReminder(
          token: token,
          rtid: rtid,
          stpid: stpid,
          thresh: thresh,
        ) &&
        kDebugMode) {
      debugPrint("setting reminder failed");
    }
    assert(!rtid.contains("|"));
  }

  static Future<void> removeReminder(String stpid, String rtid) async {
    // TODO: avoid excessive setup work
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _unsetReminder(token: token, stpid: stpid, rtid: rtid)) {
      debugPrint("unsetting reminder failed");
    }
  }

  static Future<bool?> isActiveReminder(String stpid, String rtid) async {
    final activeReminders = await getActiveReminders();
    return activeReminders?.contains((stpid: stpid, rtid: rtid));
  }

  static Future<List<({String stpid, String rtid})>?>
  getActiveReminders() async {
    final token = _serverToken();
    if (token == null) return null;
    return await _activeReminders(token: token);
  }
}

// const REMINDER_BACKEND_URL = BACKEND_URL;
// const REMINDER_BACKEND_URL = "http://10.0.2.2:3000/mbus/api/v3";
const REMINDER_BACKEND_URL = String.fromEnvironment(
  "REMINDER_BACKEND_URL",
  defaultValue: BACKEND_URL,
);

Future<List<({String stpid, String rtid})>?> _activeReminders({
  required String token,
}) async {
  final res = await http.get(
    Uri.parse('$REMINDER_BACKEND_URL/activeReminders/$token'),
  );
  if (res.statusCode == 200) {
    return (jsonDecode(res.body)['reminders'] as List)
        .map((x) => (stpid: x['stpid'] as String, rtid: x['rtid'] as String))
        .toList();
  }
  if (kDebugMode) {
    debugPrint("_activeReminders failed");
  }
  return null;
}

Future<bool> _setReminder({
  required String token,
  required String rtid,
  required String stpid,
  required int thresh,
}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/setReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'token': token,
      'rtid': rtid,
      'stpid': stpid,
      'thresh': thresh,
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
    Uri.parse('$REMINDER_BACKEND_URL/unsetReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'token': token, 'rtid': rtid, 'stpid': stpid}),
  );
  return res.statusCode == 200;
}

Future<List<({String stpid, String rtid})>?> _staleReminders({
  required String token,
  required List<({String stpid, String rtid})> currentReminders,
}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/checkStaleness'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'token': token,
      'reminders': currentReminders
          .map((x) => {"stpid": x.stpid, "rtid": x.rtid})
          .toList(),
    }),
  );
  if (res.statusCode != 200) {
    return null;
  }
  if (kDebugMode) {
    debugPrint(res.body);
  }
  try {
    final reminders = jsonDecode(res.body)['reminders'] as List;
    return reminders
        .map((x) => (stpid: x['stpid'] as String, rtid: x['rtid'] as String))
        .toList();
  } catch (e) {
    print('failed to parse response in _staleReminders: $e');
    return null;
  }
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
