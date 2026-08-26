import 'package:flutter/foundation.dart';

// Call tick() at the top of a State's build() method. Warns in the console if build()
// is firing in a rapid burst (many calls with < threshold between them), which usually
// means a setState() is being triggered from a high-frequency callback (onCameraMove,
// a position stream, an animation listener, etc) instead of only when something visible
// actually changed.
class RebuildWatchdog {
  final String label;
  final Duration threshold;
  final int consecutiveTrigger;
  DateTime? _lastBuild;
  int _rapidCount = 0;

  RebuildWatchdog(
    this.label, {
    this.threshold = const Duration(milliseconds: 20),
    this.consecutiveTrigger = 5,
  });

  void tick() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    if (_lastBuild != null && now.difference(_lastBuild!) < threshold) {
      _rapidCount++;
      if (_rapidCount == consecutiveTrigger) {
        debugPrint(
          '\x1B[33m⚠️ [$label] build() fired $consecutiveTrigger+ times <${threshold.inMilliseconds}ms apart — '
          'likely rebuilding every frame (causes low performance/stutter). Check for setState() in a high-frequency callback '
          '(onCameraMove, animation listener, build loop, etc).\x1B[0m',
        );
      }
    } else {
      _rapidCount = 0; // reset once builds slow back down, so it can fire again on a future incident
    }
    _lastBuild = now;
  }
}
