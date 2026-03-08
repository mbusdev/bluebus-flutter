import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The reminder banners that sit on the home screen on the top
class ReminderWidgets extends StatefulWidget {
  const ReminderWidgets({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ReminderWidgetsState();
  }
}

const textStyle = TextStyle(color: Colors.white, fontSize: 18);

class _ReminderWidgetsState extends State<ReminderWidgets> {
  // the future is refreshed when the app resumes or when a data message is pushed
  Future<List<({String stpid, String rtid, int? eta})>>? dataFuture;
  late final AppLifecycleListener lifecycleListener;

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
    setState(() {
      dataFuture ??= IncomingBusReminderService.getActiveRemindersNoSetup();
    });
  }

  void _resetDataFuture() {
    setState(() {
      dataFuture = IncomingBusReminderService.getActiveRemindersNoSetup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: dataFuture,
      builder: (context, snapshot) {
        var children = <Widget>[];
        if (snapshot.hasError) {
          if (kDebugMode) {
            print(snapshot.error.toString());
            children = [
              ReminderWidgetCard(
                child: Text("Failed to load reminders", style: textStyle),
              ),
            ];
          }
        } else {
          if (!snapshot.hasData) {
            // maybe replace with a loading state
            return SizedBox.shrink();
          }
          final reminders = snapshot.data!;
          reminders.sort(
            (lhs, rhs) => (lhs.eta?.toDouble() ?? double.infinity).compareTo(
              rhs.eta?.toDouble() ?? double.infinity,
            ),
          );
          children = reminders
              .map(
                (r) => ReminderWidget(
                  rtid: r.rtid,
                  stopName: getStopNameFromID(r.stpid),
                  eta: r.eta,
                ),
              )
              .toList();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
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
    required this.rtid,
    required this.stopName,
    required this.eta,
  });

  final String rtid;
  final String stopName;
  final int? eta;

  @override
  Widget build(BuildContext context) {
    return ReminderWidgetCard(
      child: Row(
        spacing: 10,
        children: [
          RouteIcon.medium(rtid, type: RouteIconType.normalWithWhiteBorder),
          Expanded(child: Text(stopName, style: textStyle)),
          Text(
            eta != null ? "${eta.toString()}\nmin" : "--\nmin",
            textAlign: TextAlign.center,
            style: textStyle,
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
        color: maizeBusBlue,
        boxShadow: [
          BoxShadow(
            blurRadius: 20.0,
            offset: Offset(0, 8),
            color: getColor(context, ColorType.mapButtonShadow),
          ),
        ],
      ),
      padding: EdgeInsetsDirectional.all(15),
      child: child,
    );
  }
}
