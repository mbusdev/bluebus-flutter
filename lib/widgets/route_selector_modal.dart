import 'dart:io';

import 'package:bluebus/globals.dart';
import 'package:bluebus/innerShadow.dart';
import 'package:bluebus/widgets/custom_sliding_segmented_control.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

// Selecting routes
class RouteSelectorModal extends StatefulWidget {
  final List<Map<String, String>> availableRoutes;
  final Set<String> initialSelectedRoutes;
  final void Function(Set<String>) onApply;
  final bool canVibrate;

  const RouteSelectorModal({
    super.key,
    required this.availableRoutes,
    required this.initialSelectedRoutes,
    required this.onApply,
    required this.canVibrate
  });

  @override
  State<RouteSelectorModal> createState() => _RouteSelectorModalState();
}

// State for the route selector
class _RouteSelectorModalState extends State<RouteSelectorModal> {
  late Set<String> tempSelectedRoutes;
  late List<Map<String, String>> michiganRoutes; // with user-selected order
  late List<Map<String, String>> rideRoutes; // with user-selected order
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _rideListKey = GlobalKey();
  bool _isReordering = false;
  int? _lastHoverIndex;
  DateTime _lastHoverHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    tempSelectedRoutes = Set<String>.from(widget.initialSelectedRoutes);

    // Initialize empty lists
    michiganRoutes = [];
    rideRoutes = [];

    // debugPrint("******* widget.availableRoutes is ${widget.availableRoutes.length}");

    // Loop through the source once and sort
    for (var route in widget.availableRoutes) {
      if (route['id'] != null && int.tryParse(route['id']!) != null) {
        // its a ride route because the id is numeric
        rideRoutes.add(route);
      } else {
        // otherwise, put in michigan routes
        michiganRoutes.add(route);
      }
    }
    
    // use the saved order from local data to reorder michigan routes
    _loadMichiganRouteOrder().then((order) {
      if (order == null) return;

      setState(() {
        michiganRoutes.sort((a, b) {
          return order.indexOf(a['id']!).compareTo(order.indexOf(b['id']!));
        });
      });
    });
    // same thing for the ride routes
    _loadRideRouteOrder().then((order) {
      if (order == null) return;

      setState(() {
        rideRoutes.sort((a, b) {
          return order.indexOf(a['id']!).compareTo(order.indexOf(b['id']!));
        });
      });
    });
  }

  // loads saved route order from local data
  Future<List<String>?> _loadMichiganRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('michigan_route_order');
  }

  // TODO: combine with _loadMichiganRouteOrder() in the future
  Future<List<String>?> _loadRideRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('ride_route_order');
  }

  // saves current route order to local data
  Future<void> _saveMichiganRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();

    // get list of route IDs
    List<String> order = michiganRoutes.map((e) => e['id']!).toList();
    await prefs.setStringList('michigan_route_order', order);
  }

  // TODO: combine with _saveMichiganRouteOrder() in the future
  Future<void> _saveRideRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();

    // get list of route IDs
    List<String> order = rideRoutes.map((e) => e['id']!).toList();
    await prefs.setStringList('ride_route_order', order);
  }

  // runs when a michigan route is reordered
  void _onMichiganReorder(int oldIndex, int newIndex) {
    _isReordering = false;
    setState(() {
      // account for index when removing the route before inserting it
      if (newIndex > oldIndex) --newIndex;

      // reorder
      final route = michiganRoutes.removeAt(oldIndex);
      michiganRoutes.insert(newIndex, route);
    });

    // save to local data
    _saveMichiganRouteOrder();
  }

  // TODO: combine with _onMichiganReorder() in the future
  void _onRideReorder(int oldIndex, int newIndex) {
    _isReordering = false;
    setState(() {
      // account for index when removing the route before inserting it
      if (newIndex > oldIndex) --newIndex;

      // reorder
      final route = rideRoutes.removeAt(oldIndex);
      rideRoutes.insert(newIndex, route);
    });

    // save to local data
    _saveRideRouteOrder();
  }

  // runs when dragging something over the list and it's hovering
  void _onDraggingMichiganRoute(PointerMoveEvent event) async {
    if (!_isReordering) return;
    if (widget.canVibrate &&
        DateTime.now().difference(_lastHoverHaptic).inMilliseconds < 10) { // hpatic rate or like cooldown
      return;
    }

    final globalPos = event.position;
    int? closestIndex;
    double closestDistance = double.infinity;

    for (int i = 0; i < michiganRoutes.length; i++) {
      final key = _itemKeys[michiganRoutes[i]['id']];
      final context = key?.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final topLeft = box.localToGlobal(Offset.zero);
      final size = box.size;
      final centerY = topLeft.dy+size.height /2;
      final dist = (globalPos.dy - centerY).abs();

      if (dist < closestDistance) {
        closestDistance = dist;
        closestIndex = i;
      }
    }

    if (closestIndex != null && closestIndex != _lastHoverIndex) {
      _lastHoverIndex = closestIndex;
      if (widget.canVibrate && Platform.isIOS) {
        _lastHoverHaptic = DateTime.now();
        await Haptics.vibrate(HapticsType.light);
      }
    }
  }

  // runs when dragging something over the list and it's hovering
  void _onDraggingRideRoute(PointerMoveEvent event) async {
    if (!_isReordering) return;
    if (widget.canVibrate &&
        DateTime.now().difference(_lastHoverHaptic).inMilliseconds < 10) { // hpatic rate or like cooldown
      return;
    }

    final globalPos = event.position;
    int? closestIndex;
    double closestDistance = double.infinity;

    for (int i = 0; i < rideRoutes.length; i++) {
      final key = _itemKeys[rideRoutes[i]['id']];
      final context = key?.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final topLeft = box.localToGlobal(Offset.zero);
      final size = box.size;
      final centerY = topLeft.dy+size.height /2;
      final dist = (globalPos.dy - centerY).abs();

      if (dist < closestDistance) {
        closestDistance = dist;
        closestIndex = i;
      }
    }

    if (closestIndex != null && closestIndex != _lastHoverIndex) {
      _lastHoverIndex = closestIndex;
      if (widget.canVibrate && Platform.isIOS) {
        _lastHoverHaptic = DateTime.now();
        await Haptics.vibrate(HapticsType.light);
      }
    }
  }

  void _onDragEnd(PointerEvent event) {
    _isReordering = false;
    _lastHoverIndex = null;
  }

  // Function to show route info
  void _showRouteInfo(String routeId, String routeName) {
    String? imagePath = _getRouteImagePath(routeId);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _RouteImageDialog(imagePath: imagePath, routeName: routeName);
      },
    );
  }

  // Map route IDs to their image file names
  String? _getRouteImagePath(String routeId) {
    // Get the route name from availableRoutes
    final route = widget.availableRoutes.firstWhere(
      (r) => r['id'] == routeId,
      orElse: () => {'id': routeId, 'name': routeId},
    );
    
    final routeName = route['name'] ?? routeId;
    final imagePath = 'assets/$routeName Route.png';
    
    return imagePath;
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {

    // pop scope lets us update busses when the modal closes
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop){
          // runs when modal closed
          widget.onApply(tempSelectedRoutes);
        }
      },

      // draggable scroll sheet is a widget that allows the modal to close when its scrolled all the way up
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.0, // leave at 0.0 to allow full dismissal
        maxChildSize: 0.9, 
        expand: false, 
        snap: true, 
        snapSizes: const [0.9], 

        builder: (BuildContext context, ScrollController scrollController) {

          // lets you control which page is shown (ride or michigan)
          final PageController pageController = PageController();

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: getColor(context, ColorType.background),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // routes list
                        PageView(
                          controller: pageController,
                          onPageChanged: (index){
                            // When swiping pages, update the selector index
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          
                          children: [
                            // MICHIGAN ROUTES PAGE
                            Listener(
                              key: _listKey,
                              behavior: HitTestBehavior.translucent,
                              onPointerMove: _onDraggingMichiganRoute,
                              onPointerUp: _onDragEnd,
                              onPointerCancel: _onDragEnd,
                              child: ReorderableListView.builder(
                                scrollController: scrollController,
                                itemCount: michiganRoutes.length,
                                
                                buildDefaultDragHandles: false,
                                onReorder: _onMichiganReorder,
                    
                                header: SizedBox(height: 70), // space for the title
                                footer: SizedBox(height: globalBottomPadding + 50), // space for slider
                            
                                // how a route looks when it's being dragged
                                proxyDecorator: (Widget child, int index, Animation<double> anim) {
                                  _isReordering = true;
                                  _lastHoverIndex = index;
                                  return Material(
                                    color: Colors.transparent,
                                    child: child,
                                  );
                                },
                            
                                itemBuilder: (context, index) {
                                  final route = michiganRoutes[index];
                                  final isSelected = tempSelectedRoutes.contains(route['id']);
                                  final key = _itemKeys.putIfAbsent(route['id']!, () => GlobalKey());
                            
                                  return KeyedSubtree(
                                    key: ValueKey(route['id']!),
                                    child: Container(
                                      key: key,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected ? getColor(context, ColorType.infoCardHighlighted) : getColor(context, ColorType.infoCardColor),
                                        borderRadius: BorderRadius.circular(60),
                                        boxShadow: isSelected? []:
                                          [getInfoCardShadow(context)]
                                      ),
                                      child: InnerShadow(
                                        isActive: isSelected,
                                        blurRadius: 5,
                                        offset: const Offset(4, 4),
                                        color: Colors.black.withAlpha(20),
                                        borderRadius: BorderRadius.circular(60),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            splashColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding: EdgeInsets.only(left: 10, right: 0), 
                                                  leading: RouteIcon.small(route['id']!),
                                                  title: Text(
                                                    route['name'] ?? route['id']!,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                                      color: getColor(context, ColorType.opposite),
                                                    ),
                                                  ),
                                                  trailing:// Info button
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.info_outline,
                                                        color: getColor(context, ColorType.opposite).withAlpha(150),
                                                        size: 22,
                                                      ),
                                                      onPressed: () {
                                                        _showRouteInfo(route['id']!, route['name'] ?? route['id']!);
                                                      },
                                                      padding: EdgeInsets.all(8),
                                                      constraints: BoxConstraints(),
                                                    ),
                                                  onTap: () {
                                                    setState(() {
                                                      if (isSelected) {
                                                        tempSelectedRoutes.remove(route['id']!);
                                                      } else {
                                                        tempSelectedRoutes.add(route['id']!);
                                                      }
                                                    });
                                                  },
                                                  onLongPress: () async {
                                                    if (widget.canVibrate){
                                                      await Haptics.vibrate(HapticsType.soft);
                                                    }
                                                    setState(() {
                                                      tempSelectedRoutes.clear();
                                                      tempSelectedRoutes.add(route['id']!);
                                                    });
                                                  },
                                                ),
                                              ),

                                              Padding(
                                                padding: const EdgeInsets.only(right: 16),
                                                child: ReorderableDragStartListener(
                                                  index: index,
                                                  child: Icon(
                                                    Icons.drag_handle,
                                                    color: getColor(context, ColorType.opposite).withAlpha(150),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        
                            // RIDE ROUTES PAGE
                            Listener(
                              key: _rideListKey,
                              behavior: HitTestBehavior.translucent,
                              onPointerMove: _onDraggingRideRoute,
                              onPointerUp: _onDragEnd,
                              onPointerCancel: _onDragEnd,
                              child: ReorderableListView.builder(
                                scrollController: scrollController,
                                itemCount: rideRoutes.length,
                                
                                buildDefaultDragHandles: false,
                                onReorder: _onRideReorder,
                    
                                header: SizedBox(height: 70), // space for the title
                                footer: SizedBox(height: globalBottomPadding + 50), // space for slider
                            
                                // how a route looks when it's being dragged
                                proxyDecorator: (Widget child, int index, Animation<double> anim) {
                                  _isReordering = true;
                                  _lastHoverIndex = index;
                                  return Material(
                                    color: Colors.transparent,
                                    child: child,
                                  );
                                },
                            
                                itemBuilder: (context, index) {
                                  final route = rideRoutes[index];
                                  final isSelected = tempSelectedRoutes.contains(route['id']);
                                  final key = _itemKeys.putIfAbsent(route['id']!, () => GlobalKey());
                            
                                  return KeyedSubtree(
                                    key: ValueKey(route['id']!),
                                    child: Container(
                                      key: key,
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected ? getColor(context, ColorType.infoCardHighlighted) : getColor(context, ColorType.infoCardColor),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: (isSelected)?[] : [getInfoCardShadow(context)],
                                      ),
                                      child: InnerShadow(
                                        isActive: isSelected,
                                        blurRadius: 5,
                                        offset: const Offset(4, 4),
                                        color: Colors.black.withAlpha(20),
                                        borderRadius: BorderRadius.circular(60),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            splashColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ListTile(
                                                  contentPadding: EdgeInsets.only(left: 8, right: 0), 
                                                  minTileHeight: 40,
                                                  leading: RouteIcon.small(route['id']!),
                                                  title: Text(
                                                    route['name'] ?? route['id']!,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                                      color: getColor(context, ColorType.opposite),
                                                    ),
                                                  ),
                                                  onTap: () {
                                                    setState(() {
                                                      if (isSelected) {
                                                        tempSelectedRoutes.remove(route['id']!);
                                                      } else {
                                                        tempSelectedRoutes.add(route['id']!);
                                                      }
                                                    });
                                                  },
                                                  onLongPress: () async {
                                                    if (widget.canVibrate){
                                                      await Haptics.vibrate(HapticsType.soft);
                                                    }
                                                    setState(() {
                                                      tempSelectedRoutes.clear();
                                                      tempSelectedRoutes.add(route['id']!);
                                                    });
                                                  },
                                                ),
                                              ),

                                              Padding(
                                                padding: const EdgeInsets.only(right: 16),
                                                child: ReorderableDragStartListener(
                                                  index: index,
                                                  child: Icon(
                                                    Icons.drag_handle,
                                                    color: getColor(context, ColorType.opposite).withAlpha(150),),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ]
                        ),
                    
                        // gradient box for title background
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 75,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  getColor(context, ColorType.background),       
                                  getColor(context, ColorType.backgroundGradientStart),  
                                ],
                                stops: [0.85, 1]
                              ),
                            ),
                          ),
                        ),
                    
                        // title
                        Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 20, top: 20, right: 20), 
                              child: Row(
                                children: [
                                  Text(
                                    'Routes',
                                    style: TextStyle(
                                      fontFamily: 'Urbanist',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30,
                                    ),
                                  ),
                                  Spacer(),
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: IconButton(
                                      padding: EdgeInsets.zero, 
                                      constraints: const BoxConstraints(), 
                                      onPressed: () {
                                        showMaizebusOKDialog(
                                          contextIn: context,
                                          title: "Route Selector",
                                          content: "Tap a route to show it on the map. Drag and drop to reorder routes. Long press to select only that route",
                                        );
                                      },
                                      style: IconButton.styleFrom(
                                        side: BorderSide(
                                          color: getColor(context, ColorType.opposite).withAlpha(150), 
                                          width: 2,
                                        ),
                                        shape: const CircleBorder(),
                                      ),
                                      icon: Icon(
                                        Icons.question_mark_rounded,
                                        color: getColor(context, ColorType.opposite).withAlpha(150),
                                        size: 15, 
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Spacer()
                          ],
                        ),
                    
                        // bottom gradient
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: IgnorePointer(
                            child: Container(
                            
                            height: globalBottomPadding + 100,
                            decoration: BoxDecoration(
                              
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                
                                colors: [
                                  getColor(context, ColorType.background).withAlpha(0),
                                  getColor(context, ColorType.background).withAlpha((255*0.8).toInt()),  
                                  getColor(context, ColorType.background).withAlpha((255*0.95).toInt()),       
                                ],
                                stops: [0, 0.5, 1]
                              ),
                            ),
                          ),
                          )
                          
                        ),
                    
                        // Slider
                        Positioned(
                          bottom: globalBottomPadding,
                          child: MaizebusSlidingSegmentedControl(
                            labels: ['University', 'TheRide'], 
                            selectedIndex: _currentIndex,
                            onSelectionChanged: (int index) {
                              // first, set the new index
                              setState(() {
                                _currentIndex = index;
                              });
                              // then, animate the change
                              pageController.animateToPage(
                                index,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            },
                            height: 40,
                            width: 250,
                            // kelevation uses flutter's default shadows - 
                            // the same ones used in elevated button
                            //shadows: kElevationToShadow[3],
                            //shadows: [getInfoCardShadow(context)]
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

// Separate widget for the image dialog with fading hint
class _RouteImageDialog extends StatefulWidget {
  final String? imagePath;
  final String routeName;

  const _RouteImageDialog({
    required this.imagePath,
    required this.routeName,
  });

  @override
  State<_RouteImageDialog> createState() => _RouteImageDialogState();
}

class _RouteImageDialogState extends State<_RouteImageDialog> {
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    // Hide the hint after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: getColor(context, ColorType.background),
      insetPadding: EdgeInsets.all(10),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Image container with zoom
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: getColor(context, ColorType.background),
                  borderRadius: BorderRadius.all(
                    Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(
                    Radius.circular(30),
                  ),
                  child: widget.imagePath != null
                      ? Stack(
                          children: [
                            InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 5.0,
                              child: Center(
                                child: Image.asset(
                                  widget.imagePath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Text(
                                          'Map image not found for ${widget.routeName}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Zoom hint at bottom center that fades
                            Positioned(
                              top: 30,
                              left: 0,
                              right: 0,
                              child: AnimatedOpacity(
                                opacity: _showHint ? 1.0 : 0.0,
                                duration: Duration(milliseconds: 500),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Pinch to zoom • Drag to pan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Back arrow at bottom left
                            Center(
                              child: Column(
                                children: [
                                  Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color: getColor(context, ColorType.importantButtonText),
                                    ),
                                    label: Text(
                                      'back',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: getColor(context, ColorType.importantButtonText)
                                      ),
                                      
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: getColor(context, ColorType.importantButtonBackground),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      elevation: 2
                                    ),
                                  ),
                                  SizedBox(height: 15,)
                                ]
                              ),
                            )
                          ],
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'No map available for ${widget.routeName}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
