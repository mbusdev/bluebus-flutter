import 'package:bluebus/services/map_layers/navigation_layer.dart';



sealed class NavigationStage {
  String title = "...";
}

class NavWalking extends NavigationStage {
  // ...
}

class NavOnBus extends NavigationStage {
  // ...
}

class NavigationManager {
  // TODO: Implement ChangeNotifier and learn how that works

  int currentStage = 0; // Stores the current navigation state index
  List<NavigationStage> stageList =
      []; // Stores all the states for users to page back and forth
  NavigationLayer? mapLayer;

  // Some way for the navigation widget to

  void init() {
    // Init as necessary
  }

  NavigationStage getCurrentStage() {
    return stageList[currentStage];
  }

  // TODO: Add start()/stop() methods
}
