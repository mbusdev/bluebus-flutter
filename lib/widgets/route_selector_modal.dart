import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../services/route_color_service.dart';

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

  @override
  void initState() {
    super.initState();
    tempSelectedRoutes = Set<String>.from(widget.initialSelectedRoutes);
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
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Info button
                                IconButton(
                                  icon: Icon(
                                    Icons.info_outline,
                                    color: Colors.grey.shade700,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    _showRouteInfo(route['id']!, route['name'] ?? route['id']!);
                                  },
                                  padding: EdgeInsets.all(8),
                                  constraints: BoxConstraints(),
                                ),
                                if (!isSelected)
                                  Icon(Icons.add),
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