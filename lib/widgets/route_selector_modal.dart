import 'package:flutter/material.dart';

// Selecting routes
class RouteSelectorModal extends StatefulWidget {
  final List<Map<String, String>> availableRoutes;
  final Set<String> initialSelectedRoutes;
  final void Function(Set<String>) onApply;

  const RouteSelectorModal({
    Key? key,
    required this.availableRoutes,
    required this.initialSelectedRoutes,
    required this.onApply,
  }) : super(key: key);

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
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop){
          // runs when modal closed
          widget.onApply(tempSelectedRoutes);
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      
          children: [
      
            // Title
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 20),
              child: const Text(
                'Routes Selector',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                ),
              ),
            ),
      
            // Subtext
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text(
                'Choose which bus routes are displayed on the map',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                ),
              ),
            ),
      
            // Scrollable list of bus routes with selection functionality
            Expanded(
              child: ListView.builder(
                itemCount: widget.availableRoutes.length,
                itemBuilder: (context, index) {
                  final route = widget.availableRoutes[index];
                  final isSelected = tempSelectedRoutes.contains(route['id']);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        Icons.directions_bus,
                        color: isSelected ? Colors.blue : Colors.grey,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 