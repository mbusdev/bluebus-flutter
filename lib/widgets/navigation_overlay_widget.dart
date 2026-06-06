
import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:flutter/material.dart';

class NavigationOverlayWidget extends StatefulWidget {

  final NavigationManager navigationManager;

  const NavigationOverlayWidget({
    super.key,
    required this.navigationManager
  });

  // TODO: add an "update callback register" command so that our NavigationManager can reach into the NavigationOverlayWidget and the map and tell them to update.

  @override
  State<StatefulWidget> createState() => _NavigationOverlayWidgetState();

}

class _NavigationOverlayWidgetState extends State<NavigationOverlayWidget> {



  @override
  Widget build(BuildContext context) {
    switch (widget.navigationManager.getCurrentStage()) {
      case NavOnBus():
        // Do stuff
      
      case NavWalking():
        // TODO: Handle this case.
        throw UnimplementedError();
    }
    return Text(widget.navigationManager.getCurrentStage().title);
  }

}

// QUESTION: Should navigation_manager