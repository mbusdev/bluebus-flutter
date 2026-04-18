import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:bluebus/widgets/refresh_button.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const reminderWidgetFg = ColorType.opposite;
const reminderWidgetBg = ColorType.infoCardColor;
const reminderWidgetsCollapsedKey = "reminderWidgetsCollapsed";

/// The reminder banners that sit on the home screen on the top
class ReminderWidgets extends StatefulWidget {
  const ReminderWidgets({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ReminderWidgetsState();
  }
}

class _ReminderWidgetsState extends State<ReminderWidgets> {
  // the future is refreshed when the app resumes or when a data message is pushed
  Future<List<({String stpid, String rtid, int? eta})>>? dataFuture;
  late final AppLifecycleListener lifecycleListener;
  SharedPreferencesWithCache? prefs;

  /// loads shared preferences object and updates state when done
  /// doesn't do anything if prefs is alread initialized
  Future<void> initPrefs() async {
    if (prefs != null) {
      return;
    }
    final newPrefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {reminderWidgetsCollapsedKey},
      ),
    );
    setState(() {
      prefs = newPrefs;
    });
  }

  @override
  void dispose() {
    super.dispose();
    lifecycleListener.dispose();
  }

  @override
  void initState() {
    super.initState();
    IncomingBusReminderService.onReminderStateChange = () {
      _resetDataFuture();
    };
    lifecycleListener = AppLifecycleListener(
      onResume: () {
        _resetDataFuture();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // mock data
    // dataFuture ??= Future.value([
    //   (stpid: "C250", rtid: "BB", eta: null),
    //   (stpid: "C250", rtid: "BB", eta: 6),
    //   (stpid: "C250", rtid: "BB", eta: 1),
    // ]);
    if (dataFuture == null) {
      _resetDataFuture();
    }
  }

  /// tell the widget to fetch new reminder data, also used to initialize prefs during startup
  void _resetDataFuture() {
    setState(() {
      dataFuture = initPrefs().then(
        (void _) => IncomingBusReminderService.getActiveRemindersNoSetup(),
      );
    });
  }

  /// are reminders collapsed? (assume true if unsure)
  bool collapsed() {
    return prefs?.getBool(reminderWidgetsCollapsedKey) ?? true;
  }

  /// expands reminders (does nothing if prefs is initialized)
  void expand() {
    prefs?.setBool(reminderWidgetsCollapsedKey, false);
    setState(() {});
  }

  /// toggles reminders (does nothing if prefs is initialized)
  void toggle() {
    final isCollapsed = collapsed();
    prefs?.setBool(reminderWidgetsCollapsedKey, !isCollapsed);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: dataFuture,
      builder: (context, snapshot) {
        var children = <Widget>[];
        if (snapshot.hasError &&
            snapshot.connectionState == ConnectionState.done) {
          // error state
          if (kDebugMode) {
            print(snapshot.error.toString());
          }
          children.add(
            ReminderWidgetCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Failed to load reminders, try again",
                    style: getTextStyle(
                      TextType.normal,
                      // the error color was chosen to look nice over a card and doesn't look too good on top of maizebusblue
                      getColor(context, ColorType.error),
                    ),
                  ),
                  RefreshButton(
                    loading: false,
                    onTap: () {
                      _resetDataFuture();
                      expand();
                    },
                    refreshIconColor: getColor(context, ColorType.error),
                  ),
                ],
              ),
            ),
          );
        } else {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // loading state
            children.add(
              InkWell(
                onTap: () {
                  toggle();
                },
                child: ReminderWidgetCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Refreshing reminders",
                        style: getTextStyle(
                          TextType.normal,
                          getColor(context, reminderWidgetFg),
                        ),
                      ),
                      RefreshButton(loading: true),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // normal header, only present if more than 0 reminders
            final numReminders = snapshot.data?.length ?? 0;
            if (numReminders > 0) {
              children.add(
                GestureDetector(
                  onTap: () {
                    toggle();
                  },
                  child: ReminderWidgetCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$numReminders reminder${numReminders == 1 ? '' : 's'}",
                          style: getTextStyle(
                            TextType.normal,
                            getColor(context, reminderWidgetFg),
                          ),
                        ),
                        collapsed()
                            ? Icon(Icons.expand_more)
                            : Icon(Icons.expand_less),
                      ],
                    ),
                  ),
                ),
              );
            }
          }
          if (!collapsed() && snapshot.data != null) {
            // show widgets if we know it is not collasped
            final reminders = snapshot.data!;
            reminders.sort(
              (lhs, rhs) => (lhs.eta?.toDouble() ?? double.infinity).compareTo(
                rhs.eta?.toDouble() ?? double.infinity,
              ),
            );
            children.addAll(
              // the dismissible widgets that show each reminder, swiping left deletes the reminder.
              // using a custom implementation instead of Dismissible
              reminders.map(
                (r) => _DismissibleReminder(
                  key: Key('${r.stpid}|${r.rtid}'),
                  stpid: r.stpid,
                  rtid: r.rtid,
                  stopName: getStopNameFromID(r.stpid),
                  eta: r.eta,
                  confirmDismiss: () async {
                    try {
                      await IncomingBusReminderService.removeReminder(
                        r.stpid,
                        r.rtid,
                      );
                      return true;
                    } catch (e) {
                      if (kDebugMode) {
                        print('Failed to remove reminder: $e');
                      }
                      return false;
                    }
                  },
                  onDismissed: () {
                    setState(() {
                      reminders.removeWhere(
                        (x) => x.stpid == r.stpid && x.rtid == r.rtid,
                      );
                    });
                    _resetDataFuture();
                  },
                ),
              ),
            );
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 10.0,
          children: children,
        );
      },
    );
  }
}

class ReminderWidget extends StatelessWidget {
  const ReminderWidget({
    super.key,
    required this.stpid,
    required this.rtid,
    required this.stopName,
    required this.eta,
    this.onDismissed,
  });

  final String stpid;
  final String rtid;
  final String stopName;
  final int? eta;
  final VoidCallback? onDismissed; // called when the reminder is dismissed

  @override
  Widget build(BuildContext context) {
    return ReminderWidgetCard(
      child: Row(
        spacing: 10,
        children: [
          RouteIcon.medium(rtid),
          Expanded(
            child: Text(
              stopName,
              style: getTextStyle(
                TextType.normal,
                getColor(context, reminderWidgetFg),
              ),
            ),
          ),
          Text(
            eta != null ? "${eta.toString()}\nmin" : "--\nmin",
            textAlign: TextAlign.center,
            style: getTextStyle(
              TextType.normal,
              getColor(context, reminderWidgetFg),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderWidgetCard extends StatelessWidget {
  const ReminderWidgetCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(30)),
        color: getColor(context, reminderWidgetBg),
        boxShadow: [
          BoxShadow(
            color: getColor(context, ColorType.mapButtonShadow).withAlpha(40), // making it a little less strong
            blurRadius: 10,
            offset: Offset(0, 6)
          )
        ],
      ),
      padding: EdgeInsetsDirectional.all(15),
      child: child,
    );
  }
}

/// Custom swipe for dismissing notifications:
/// white card slides left revealing the red behind it,
/// then on dismiss both animate off screen together (red pulled along by the card).
class _DismissibleReminder extends StatefulWidget {
  const _DismissibleReminder({
    super.key,
    required this.stpid,
    required this.rtid,
    required this.stopName,
    required this.eta,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  final String stpid;
  final String rtid;
  final String stopName;
  final int? eta;
  final Future<bool> Function() confirmDismiss; // returns whether the dismissal should proceed (like if the reminder was successfully deleted)
  final VoidCallback onDismissed; // called after the dismiss animation completes and the widget is removed from the tree

  @override
  State<_DismissibleReminder> createState() => __DismissibleReminderState();
}


class __DismissibleReminderState extends State<_DismissibleReminder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;


  // current drag offset (always <= 0)
  double _dragOffset = 0.0;
  // offset captured when the dismiss animation starts
  double _capturedOffset = 0.0;
  bool _dismissing = false;
  bool _dismissed = false;
  // row width measured by LayoutBuilder
  double _rowWidth = 300.0;



  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  // white card: slides from capturedOffset to -rowWidth
  double get _whiteX {
    if (_dismissing) {
      return _capturedOffset + _curve.value * (-_rowWidth - _capturedOffset);
    }
    return _dragOffset;
  }



  // red background: stays at 0 during drag, then accelerates to -rowWidth on dismiss
  double get _redX {
    if (_dismissing) {
      return _curve.value * (-_rowWidth);
    }
    return 0.0;
  }



  // updates drag offset during horizontal drag, ignoring drags if already dismissing
  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_rowWidth,
        0.0,
      );
    });
  }



  // handles drag end, checking if the drag was far/fast enough to 
  // dismiss, then either starts the dismiss animation or resets the drag offset
  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_dismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    // dismiss if dragged more than 35% of the way or swiped left fast enough, otherwise reset
    if (_dragOffset.abs() > _rowWidth * 0.35 || velocity < -700) {
      final confirmed = await widget.confirmDismiss();
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _dragOffset = 0.0; // reset position if dismissal was not confirmed
        });
        return;
      }
      _capturedOffset = _dragOffset;
      setState(() {
        _dismissing = true; // trigger animation to start sliding both widgets left
      });
      await _controller.forward();
      if (!mounted) return;
      setState(() {
        _dismissed = true; // hide the widget after animation completes
      });
      widget.onDismissed();
    } else {
      setState(() {
        _dragOffset = 0.0; // reset position if dismissal was not confirmed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink(); // don't build anything if dismissed
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite) {
          _rowWidth = constraints.maxWidth; // update row width based on layout constraints
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // red delete background — revealed as white slides, pulled off screen on dismiss
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(_redX, 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                    color: Colors.red,
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ),
            ),
            // white notification card — follows drag, animates off screen on dismiss
            Transform.translate(
              offset: Offset(_whiteX, 0),
              child: GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: ReminderWidget(
                  stpid: widget.stpid,
                  rtid: widget.rtid,
                  stopName: widget.stopName,
                  eta: widget.eta,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
