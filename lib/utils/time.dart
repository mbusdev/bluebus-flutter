
// utc secs after midnight -> michigan time
import 'package:intl/intl.dart';

String convertSecondsToFormattedTime(int secondsFromMidnightUtc) {
  final now = DateTime.now().toUtc();
  final midnightUtc = DateTime.utc(now.year, now.month, now.day);
  final timeUtc = midnightUtc.add(Duration(seconds: secondsFromMidnightUtc));

  // Convert the UTC time to the local timezone.
  final localTime = timeUtc.toLocal();

  // Use the DateFormat class to format the local time string.
  return DateFormat('h:mm a').format(localTime);
}

