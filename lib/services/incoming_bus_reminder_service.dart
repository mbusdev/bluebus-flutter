import 'dart:async';

import 'package:bluebus/services/bus_info_service.dart';
import 'package:bluebus/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _updateInterval = Duration(minutes: 1);
// Avoid spamming notifications
const _notificationWaitTime = Duration(seconds: 1);
const reminderThreshold = 5;
const remindersKey = "bus_reminder";

class IncomingBusReminderService {
  static late SharedPreferencesWithCache userPrefs;
  static late Timer _timer;
  static Map<({String stpid, String rtid}), int> prevArrivalInfo = {};

  static void start() async {
    userPrefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {remindersKey},
      ),
    );
    _timer = Timer.periodic(_updateInterval, (_) async {
      if (kDebugMode) {
        debugPrint("Doing reminder processing...");
      }
      try {
        final reminders = getActiveReminders();
        final stops = reminders.map((x) => x.stpid).toSet();
        final incomingBusResults = Stream.fromFutures(
          stops.map((stop) async {
            return (stop, await fetchStopData(stop));
          }),
        );

        final Map<({String stpid, String rtid}), int> currArrivalInfo = {};
        await for (final (stop, (buses, _)) in incomingBusResults) {
          for (final bus in buses) {
            final event = (rtid: bus.id, stpid: stop);
            final prediction = bus.prediction == 'DUE'
                ? 0
                : int.parse(bus.prediction);
            if (currArrivalInfo[event] == null ||
                currArrivalInfo[event]! > prediction) {
              currArrivalInfo[event] = prediction;
            }
          }
        }

        for (final entry in currArrivalInfo.entries) {
          if (entry.value <= reminderThreshold &&
              (!prevArrivalInfo.containsKey(entry.key) ||
                  prevArrivalInfo[entry.key]! > reminderThreshold)) {
            NotificationService.sendNotification(
              "Bus Alert",
              "${entry.key.rtid} will be at ${entry.key.stpid}",
            );
            await Future.delayed(_notificationWaitTime);
          }
        }
      } catch (e) {
        print("Reminder processing failed with: $e");
      }
      if (kDebugMode) {
        print("Reminder processing finished");
      }
    });
  }

  static Future<void> addReminder(String stpid, String rtid) async {
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
    assert(!rtid.contains("|"));
    final activeReminders = userPrefs.getStringList(remindersKey);
    if (activeReminders == null) {
      return;
    }
    if (activeReminders.contains("$rtid|$stpid")) {
      activeReminders.remove("$rtid $stpid");
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
