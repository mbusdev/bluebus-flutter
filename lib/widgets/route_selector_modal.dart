import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/route_color_service.dart';
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
  late List<Map<String, String>> displayedRoutes; // with user-selected order
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _listKey = GlobalKey();
  bool _isReordering = false;
  int? _lastHoverIndex;
  DateTime _lastHoverHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    tempSelectedRoutes = Set<String>.from(widget.initialSelectedRoutes);
    displayedRoutes = List<Map<String, String>>.from(widget.availableRoutes); // set to default order
    
    // update displayedRoutes after loaded from user save data
    _loadRouteOrder().then((order) {
      if (order == null) return;

      setState(() {
        displayedRoutes.sort((a, b) {
          return order.indexOf(a['id']!).compareTo(order.indexOf(b['id']!));
        });
      });
    });
  }

  Future<List<String>?> _loadRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('route_order');
  }

  Future<void> _saveRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();

    // get list of route IDs
    List<String> order = displayedRoutes.map((e) => e['id']!).toList();
    await prefs.setStringList('route_order', order);
  }

  void _onReorder(int oldIndex, int newIndex) {
    _isReordering = false;
    setState(() {
      // account for index when removing the route before inserting it
      if (newIndex > oldIndex) --newIndex;

      // reorder
      final route = displayedRoutes.removeAt(oldIndex);
      displayedRoutes.insert(newIndex, route);
    });

    // save to local data
    _saveRouteOrder();
  }

  void _onDragHover(PointerMoveEvent event) async {
    if (!_isReordering) return;
    if (widget.canVibrate &&
        DateTime.now().difference(_lastHoverHaptic).inMilliseconds < 60) { // hpatic rate or like cooldown
      return;
    }

    final globalPos = event.position;
    int? closestIndex;
    double closestDistance = double.infinity;

    for (int i = 0; i < displayedRoutes.length; i++) {
      final key = _itemKeys[displayedRoutes[i]['id']];
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
      if (widget.canVibrate) {
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
        initialChildSize: 0.8,
        minChildSize: 0.0, // leave at 0.0 to allow full dismissal
        maxChildSize: 0.9, 
        expand: false, 
        snap: true, 
        snapSizes: const [0.9], 

        builder: (BuildContext context, ScrollController scrollController) {

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: getColor(context, ColorType.background),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 20, bottom: 4), 
                  child: Text(
                    'Select Routes',
                    style: TextStyle(
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                ),

                // description
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 14, right: 20), 
                  child: Text(
                    'Choose which bus routes are displayed on the map. Long press a route to show only that one.',
                    style: TextStyle(
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w400,
                      fontSize: 18,
                    ),
                  ),
                ),

                // routes list
                Expanded(
                  child: Listener(
                    key: _listKey,
                    behavior: HitTestBehavior.translucent,
                    onPointerMove: _onDragHover,
                    onPointerUp: _onDragEnd,
                    onPointerCancel: _onDragEnd,
                    child: ReorderableListView.builder(
                      scrollController: scrollController,
                      itemCount: displayedRoutes.length,
                      
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,

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
                        final route = displayedRoutes[index];
                        final isSelected = tempSelectedRoutes.contains(route['id']);
                        final key = _itemKeys.putIfAbsent(route['id']!, () => GlobalKey());

                        return KeyedSubtree(
                          key: ValueKey(route['id']!),
                          child: Card(
                            key: key,
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            color: isSelected ? getColor(context, ColorType.highlighted) : getColor(context, ColorType.dim),
                            // Increase elevation when selected
                            elevation: 2,
                            shadowColor: getColor(context, ColorType.mapButtonShadow),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: RouteColorService.getRouteColor(route['id']!), 
                                  ),
                                  alignment: Alignment.center,
                                  child: MediaQuery(
                                    // media query prevents text scaling
                                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                                    child: Text(
                                      route['id']!,
                                      style: TextStyle(
                                        color: RouteColorService.getContrastingColor(route['id']!), 
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  route['name'] ?? route['id']!,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                    shadows: [
                                      Shadow(
                                        color: getColor(context, ColorType.mapButtonShadow),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Info button
                                    IconButton(
                                      icon: Icon(Icons.info_outline, size: 22,),
                                      onPressed: () {
                                        _showRouteInfo(route['id']!, route['name'] ?? route['id']!);
                                      },
                                      padding: EdgeInsets.all(8),
                                      constraints: BoxConstraints(),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ],
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
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),
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
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(10),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header with route name
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.routeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Urbanist',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Image container with zoom
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
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
                              bottom: 15,
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Back arrow at bottom left
                            Positioned(
                              bottom: 15,
                              left: 15,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                                  padding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
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
