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
              color: getColor(context, 'background'),
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
                  child: ReorderableListView.builder(
                    scrollController: scrollController,
                    itemCount: displayedRoutes.length,
                    
                    buildDefaultDragHandles: false,
                    onReorder: _onReorder,

                    // how a route looks when it's being dragged
                    proxyDecorator: (Widget child, int index, Animation<double> anim) {
                      return Material(
                        color: Colors.transparent,
                        child: child,
                      );
                    },

                    itemBuilder: (context, index) {
                      final route = displayedRoutes[index];
                      final isSelected = tempSelectedRoutes.contains(route['id']);

                      return Card(
                        key: ValueKey(route['id']!),
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        color: isSelected ? getColor(context, 'highlighted') : getColor(context, 'dim'),
                        // Increase elevation when selected
                        elevation: 2,
                        shadowColor: getColor(context, 'mapButtonShadow'),
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
                                    color: getColor(context, 'mapButtonShadow'),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4
                                  ),
                                ],
                              ),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Icon(Icons.drag_handle),
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
                      );
                    },
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