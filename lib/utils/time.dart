
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

const int _secondsPerDay = 86400;

/// Turns a journey time (seconds after midnight UTC) into an absolute DateTime.
///
/// Ann Arbor evenings cross UTC midnight, and it's undocumented whether the
/// backend keeps counting past 86400 or wraps back to 0, so anchoring on
/// today's UTC date alone can land a day off. Instead we try yesterday, today
/// and tomorrow and keep whichever is closest to [now]. That's right for any
/// time within 12 hours of [now], which covers an active trip.
DateTime serviceSecondsToDateTime(int seconds, {DateTime? now}) {
  final DateTime nowUtc = (now ?? DateTime.now()).toUtc();
  final DateTime candidate = DateTime.utc(
    nowUtc.year,
    nowUtc.month,
    nowUtc.day,
  ).add(Duration(seconds: seconds));

  DateTime best = candidate;
  for (final int dayOffset in const [-1, 1]) {
    final DateTime shifted = candidate.add(Duration(days: dayOffset));
    if (shifted.difference(nowUtc).abs() < best.difference(nowUtc).abs()) {
      best = shifted;
    }
  }
  return best;
}

/// Seconds from [from] to [to], both seconds after midnight UTC. If [to] has
/// wrapped past midnight (e.g. 86300 -> 100) the difference would come out
/// negative, so add a day back.
int serviceSecondsBetween(int from, int to) {
  final int diff = to - from;
  return diff < 0 ? diff + _secondsPerDay : diff;
}

