import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';
import '../services/route_color_service.dart';

// Selecting routes
class RouteSelectorModal extends StatefulWidget {
  final List<Map<String, String>> availableRoutes;
  final Set<String> initialSelectedRoutes;
  final void Function(Set<String>) onApply;

  const RouteSelectorModal({
    super.key,
    required this.availableRoutes,
    required this.initialSelectedRoutes,
    required this.onApply,
  });

  @override
  State<RouteSelectorModal> createState() => _RouteSelectorModalState();
}

// State for the route selector
class _RouteSelectorModalState extends State<RouteSelectorModal> {
  late Set<String> tempSelectedRoutes;

  @override
  void initState() {
    super.initState();
    tempSelectedRoutes = Set<String>.from(widget.initialSelectedRoutes);
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),

            child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.availableRoutes.length + 2,
                  itemBuilder: (context, index) {

                  // TITLE
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 20, top: 20, bottom: 4), 
                      child: Text(
                        'Routes Selector',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                        ),
                      ),
                    );

                  // SUBTITLE
                  } else if (index == 1) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 14, right: 20), 
                      child: Text(
                        'Choose which bus routes are displayed on the map. Long press a route to show only that one.',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                        ),
                      ),
                    );

                  // ACTUAL LIST
                  } else {
                      final route = widget.availableRoutes[index - 2]; // -2 to account for title and subtitle
                      final isSelected = tempSelectedRoutes.contains(route['id']);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        color: isSelected ? Colors.blue.shade200 : Color.fromARGB(255, 235, 235, 235),
                        // Increase elevation when selected
                        elevation: isSelected ? 6.0 : 2.0,
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
                            title: Text(
                              route['name'] ?? route['id']!,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                            trailing: (isSelected)? SizedBox.shrink() : Icon(Icons.add),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  tempSelectedRoutes.remove(route['id']!);
                                } else {
                                  tempSelectedRoutes.add(route['id']!);
                                }
                              });
                            },
                          ),
                        ),
                      );
                  }
              },
            ),
          );
        }
      ),
    );
  }
} 