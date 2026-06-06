import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:flutter/material.dart';

// TODO: Extend the MapController back to map_screen.dart so it can move the camera and stuff

class NavigationWidget extends StatefulWidget {
  final NavigationManager navigationManager;

  NavigationWidget({required this.navigationManager});

  @override
  State<StatefulWidget> createState() {
    return NavigationWidgetState();
  }
}

class NavigationWidgetState extends State<NavigationWidget>
    with SingleTickerProviderStateMixin {
  // NEXT STEPS TODO: Add a very simple navigation tracking UI to show the current stage

  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return null; // TODO: Return some widget stuff
  }
}
