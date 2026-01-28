import 'package:bluebus/globals.dart';
import 'package:bluebus/services/incoming_bus_reminder_service.dart';
import 'package:flutter/material.dart';

class ReminderWidgets extends StatefulWidget {
  const ReminderWidgets({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ReminderWidgetsState();
  }
}

class _ReminderWidgetsState extends State<ReminderWidgets> {
  Future<List<({String stpid, String rtid, int? eta})>>? dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // mock data
    dataFuture ??= Future.value([
      (stpid: "C250", rtid: "BB", eta: null),
      (stpid: "C250", rtid: "BB", eta: 6),
      (stpid: "C250", rtid: "BB", eta: 1),
    ]);
    // dataFuture ??= IncomingBusReminderService.getActiveRemindersNoSetup();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          print("${snapshot.error}");
          return Placeholder();
        }
        final reminders = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: reminders
              .map(
                (r) => ReminderWidget(
                  rtid: r.rtid,
                  stopName: getStopNameFromID(r.stpid),
                  eta: r.eta,
                ),
              )
              .toList(),
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
    return Row(
      children: [
        Text(rtid),
        Text(stopName),
        Spacer(),
        Text(eta != null ? eta.toString() : "unknown"),
      ],
    );
  }
}
