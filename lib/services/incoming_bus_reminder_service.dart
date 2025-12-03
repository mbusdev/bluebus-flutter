import 'dart:async';
import 'dart:convert';

import 'package:bluebus/constants.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const remindersKey = "bus_reminder";

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
        allowList: {remindersKey, serverTokenKey},
      ),
    );
    if (_serverToken() != null) {
      // notifications were used before, sync with backend and complete setup

      // TODO: make sure this won't lead to constant permission requests
      // for someone who has denied notifications
      await _completeSetup();
      var staleReminders = await _staleReminders(
        token: _serverToken()!,
        currentReminders: getActiveReminders().toList(),
      );
      if (staleReminders == null) {
        staleReminders = [];
        print('Failed to get stale reminders!');
      }
      if (kDebugMode) {
        debugPrint('Got stale reminders: $staleReminders');
      }
      for (final stale in staleReminders) {
        removeReminderWithoutSyncing(stale.stpid, stale.rtid);
      }
    }
  }

  static Future<void> _completeSetup() async {
    NotificationService.setTokenChangeCallback(_onTokenChange);
    await NotificationService.requestPermission();
    String? currToken = NotificationService.token();
    if (currToken != null && currToken != _serverToken()) {
      await _onTokenChange(currToken);
    }
  }

  static String? _serverToken() {
    return _userPrefs.getString(serverTokenKey);
  }

  static Future<void> _onTokenChange(String token) async {
    final serverToken = _serverToken();
    if (serverToken != null) {
      if (!await _swapToken(oldTok: _serverToken()!, newTok: token)) {
        print("swap token FAILED");
      }
    }
    _userPrefs.setString(serverTokenKey, token);
  }

  static Future<void> addReminder(String stpid, String rtid) async {
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _setReminder(token: token, rtid: rtid, stpid: stpid) &&
        kDebugMode) {
      debugPrint("setting reminder failed");
    }
    assert(!rtid.contains("|"));
    var activeReminders = _userPrefs.getStringList(remindersKey);
    activeReminders ??= [];
    activeReminders.add("$rtid|$stpid");
    if (kDebugMode) {
      debugPrint("reminders is now $activeReminders");
    }
    await _userPrefs.setStringList(remindersKey, activeReminders);
  }

  static Future<void> removeReminderWithoutSyncing(
    String stpid,
    String rtid,
  ) async {
    assert(!rtid.contains("|"));
    final activeReminders = _userPrefs.getStringList(remindersKey);
    if (activeReminders == null) {
      return;
    }
    if (activeReminders.contains("$rtid|$stpid")) {
      activeReminders.remove("$rtid|$stpid");
      if (kDebugMode) {
        debugPrint("reminders is now $activeReminders");
      }
      await _userPrefs.setStringList(remindersKey, activeReminders);
    }
  }

  static Future<void> removeReminder(String stpid, String rtid) async {
    // TODO: avoid excessive setup work
    await _completeSetup();
    final token = _serverToken();
    if (token == null) return;
    if (!await _unsetReminder(token: token, stpid: stpid, rtid: rtid)) {
      debugPrint("unsetting reminder failed");
    }
    await removeReminderWithoutSyncing(stpid, rtid);
  }

  static bool isActiveReminder(String stpid, String rtid) {
    final activeReminders = getActiveReminders();
    return activeReminders.contains((stpid: stpid, rtid: rtid));
  }

  static Set<({String stpid, String rtid})> getActiveReminders() {
    var activeReminders = _userPrefs.getStringList(remindersKey);
    activeReminders ??= [];
    return activeReminders
        .map((x) => x.split('|'))
        .map((parts) => (stpid: parts[1], rtid: parts[0]))
        .toSet();
  }
}

// const REMINDER_BACKEND_URL = BACKEND_URL;
// const REMINDER_BACKEND_URL = "http://10.0.2.2:3000/mbus/api/v3";
const REMINDER_BACKEND_URL = String.fromEnvironment("REMINDER_BACKEND_URL", defaultValue: BACKEND_URL);

Future<bool> _setReminder({
  required String token,
  required String rtid,
  required String stpid,
}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/setReminder'),
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
    Uri.parse('$REMINDER_BACKEND_URL/unsetReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'token': token,
      'event': {'rtid': rtid, 'stpid': stpid},
    }),
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
