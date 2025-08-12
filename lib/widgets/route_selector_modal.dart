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
                      padding: EdgeInsets.only(left: 16, top: 20, bottom: 4), 
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
                      padding: EdgeInsets.only(left: 16, bottom: 16, right: 16), 
                      child: Text(
                        'Choose which bus routes are displayed on the map',
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
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 47,
                            height: 47,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RouteColorService.getRouteColor(route['id']!), 
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              route['id']!,
                              style: TextStyle(
                                color: RouteColorService.getContrastingColor(route['id']!), 
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          title: Text(
                            route['name'] ?? route['id']!,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempSelectedRoutes.add(route['id']!);
                                } else {
                                  tempSelectedRoutes.remove(route['id']!);
                                }
                              });
                            },
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