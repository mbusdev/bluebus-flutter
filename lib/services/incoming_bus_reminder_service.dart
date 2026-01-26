import 'dart:async';
import 'dart:convert';

import 'package:bluebus/constants.dart';
import 'package:bluebus/services/notification_service.dart';
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
      await _swapToken(oldTok: serverToken, newTok: token);
    }
    _userPrefs.setString(serverTokenKey, token);
  }

  static Future<void> addReminder(String stpid, String rtid, int thresh) async {
    assert(!rtid.contains('|') && !stpid.contains('|'));
    await _completeSetup();
    final token = _serverToken();
    if (token == null) throw Exception("missing token");
    await _setReminder(token: token, rtid: rtid, stpid: stpid, thresh: thresh);
  }

  static Future<void> removeReminder(String stpid, String rtid) async {
    // TODO: avoid excessive setup work
    await _completeSetup();
    final token = _serverToken();
    if (token == null) throw Exception("missing token");
    await _unsetReminder(token: token, stpid: stpid, rtid: rtid);
  }

  static Future<void> modifyReminders(
    List<RemindersModification> modifications,
  ) async {
    // TODO: avoid excessive setup work
    await _completeSetup();
    final token = _serverToken();
    if (token == null) throw Exception("missing token");
    await _modifyReminders(token: token, modifications: modifications);
  }

  static Future<bool> isActiveReminder(String stpid, String rtid) async {
    final activeReminders = await getActiveReminders();
    return activeReminders.contains((stpid: stpid, rtid: rtid));
  }

  static Future<List<({String stpid, String rtid})>>
  getActiveReminders() async {
    await _completeSetup();
    final token = _serverToken();
    if (token == null) throw Exception("missing token");
    return await _activeReminders(token: token);
  }

  static Future<void> sendTestNotification() async {
    await _completeSetup();
    final token = _serverToken();
    if (token == null) throw Exception("missing token");
    await _notifyMeLater(token: token);
  }
}

// const REMINDER_BACKEND_URL = BACKEND_URL;
// const REMINDER_BACKEND_URL = "http://10.0.2.2:3000/mbus/api/v3";
const REMINDER_BACKEND_URL = String.fromEnvironment(
  "REMINDER_BACKEND_URL",
  defaultValue: BACKEND_URL,
);

Future<List<({String stpid, String rtid})>> _activeReminders({
  required String token,
}) async {
  final uri = Uri.parse(
    '$REMINDER_BACKEND_URL/activeReminders/${Uri.encodeComponent(token)}',
  );
  final res = await http.get(uri);
  if (res.statusCode == 200) {
    return (jsonDecode(res.body)['reminders'] as List)
        .map((x) => (stpid: x['stpid'] as String, rtid: x['rtid'] as String))
        .toList();
  }
  throw Exception(res.body);
}

Future<void> _setReminder({
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
  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
}

Future<void> _unsetReminder({
  required String token,
  required String rtid,
  required String stpid,
}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/unsetReminder'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'token': token, 'rtid': rtid, 'stpid': stpid}),
  );
  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
}

Future<void> _modifyReminders({
  required String token,
  required List<RemindersModification> modifications,
}) async {
  final uri = Uri.parse('$REMINDER_BACKEND_URL/modifyReminders');
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "token": token,
      "modifications": modifications.map((x) => x.encode()).toList(),
    }),
  );
  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
}

Future<void> _swapToken({
  required String oldTok,
  required String newTok,
}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/swapToken'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'oldTok': oldTok, 'newTok': newTok}),
  );
  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
}

Future<void> _notifyMeLater({required String token}) async {
  final res = await http.post(
    Uri.parse('$REMINDER_BACKEND_URL/notifyMeLater'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'token': token}),
  );
  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
}

/// Used in the `modifyReminders` method of `IncomingBusReminderService`
sealed class RemindersModification {
  Map<String, dynamic> encode();
}

class AddReminder extends RemindersModification {
  AddReminder({required this.stpid, required this.rtid, required this.thresh});

  String stpid, rtid;
  int thresh;

  @override
  Map<String, dynamic> encode() {
    return {"action": "set", "stpid": stpid, "rtid": rtid, "thresh": thresh};
  }
}

class RemoveReminder extends RemindersModification {
  RemoveReminder({required this.stpid, required this.rtid});

  String stpid, rtid;

  @override
  Map<String, dynamic> encode() {
    return {"action": "unset", "stpid": stpid, "rtid": rtid};
  }
}
