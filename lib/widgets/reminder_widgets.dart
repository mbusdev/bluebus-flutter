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
              // the dismissible widgets that show each reminder, swiping left deletes the reminder
              reminders.map(
                (r) => ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                            color: Colors.red,
                          ),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20.0),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                      Dismissible(
                        key: Key('${r.stpid}|${r.rtid}'),
                        direction: DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        // when the user swipes enough to dismiss
                        // try to remove the reminder from the service
                        // if it fails put the widget back
                        confirmDismiss: (direction) async {
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
                        // if the reminder was successfully removed from the service
                        // also remove it from the local list so the widget disappears immediately
                        onDismissed: (_) {
                          // Remove from local list immediately so the dismissed
                          // widget leaves the tree before the async refresh.
                          setState(() {
                            reminders.removeWhere(
                              (x) => x.stpid == r.stpid && x.rtid == r.rtid,
                            );
                          });
                          _resetDataFuture();
                        },
                        // the actual reminder widget
                        child: ReminderWidget(
                          stpid: r.stpid,
                          rtid: r.rtid,
                          stopName: getStopNameFromID(r.stpid),
                          eta: r.eta,
                          onDismissed: _resetDataFuture,
                        ),
                      ),
                    ],
                  ),
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
