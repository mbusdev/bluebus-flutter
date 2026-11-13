import 'dart:async';
import 'dart:math';

import 'package:bluebus/constants.dart';
import 'package:bluebus/globals.dart';
import 'package:bluebus/models/bus.dart';
import 'package:bluebus/services/journey_repository.dart';
import 'package:bluebus/services/navigation/navigation_manager.dart';
import 'package:bluebus/widgets/dialog.dart';
import 'package:bluebus/widgets/floating_draggable_sheet.dart';
import 'package:bluebus/utils/time.dart';
import 'package:bluebus/widgets/route_icon.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationOverlay extends StatefulWidget {
  final NavigationManager navigationManager;

  const NavigationOverlay({super.key, required this.navigationManager});

  // TODO: add an "update callback register" command so that our NavigationManager can reach into the NavigationOverlayWidget and the map and tell them to update.

  @override
  State<StatefulWidget> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay>
    implements NavigationOverlayHost {
  bool planJourneyInProgress = false;
  TimelineInfo timelineInfo = TimelineInfo();

  // Fraction of the screen the sheet occupies with nothing but the progress bar
  // in it. TODO: Compute this from the progress bar instead of hardcoding it.
  static const double _sheetCollapsed = 0.14;
  static const double _sheetExpanded = 0.85;

  // Ours (not the sheet's) so we can watch the drag progress from out here.
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // The prompt is pinned below the scrollable, so the collapsed sheet has to
  // grow by however tall the prompt turns out to be.
  final GlobalKey _promptKey = GlobalKey();
  double _promptHeight = 0.0;

  double get _collapsedSize =>
      _sheetCollapsed + (_promptHeight / MediaQuery.sizeOf(context).height);

  /// 0 while the sheet is collapsed, 1 once it's fully expanded.
  double _sheetProgress() {
    if (!_sheetController.isAttached) return 0.0;
    final double minSize = _collapsedSize;
    return ((_sheetController.size - minSize) /
            max(_sheetExpanded - minSize, 0.0001))
        .clamp(0.0, 1.0);
  }

  void updateTimeline() {
    // Call this after all the stages are loaded (or stages change)
    timelineInfo = widget.navigationManager.getTimeline();
  }

  @override
  void initState() {
    super.initState();
    updateTimeline();
    widget.navigationManager.registerOverlay(
      this,
    ); // does not set to null, see the navigation manager

    // GPS fixes redraw the overlay, but standing still (eg. waiting at a
    // stop) produces none, so this keeps the minutes until arrival counting.
    _etaTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Timer? _etaTicker;

  @override
  void dispose() {
    // sets to null
    widget.navigationManager.unregisterOverlay(this);
    _etaTicker?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void onNavigationUpdated() {
    setState(() {
      // called from the nav manager, updates stuff
      updateTimeline();
    });
  }

  // the regular busOptions button
  // NOTE: Currently not in use to match UI refactor but will leave it here for someone to use maybe
  Widget busOptionButton(Bus bus, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: bus.routeColor,
                child: Text(
                  bus.routeId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bus.id,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC94A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "1",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ), // NOTE: Mock using number 1, need to double check with Bus class
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Special missedBusButton widget to trigger a reroute later...
  // Notes: Can choose custom text, and an optional leading icon.
  // No fixed width--wrap it in an Expanded/SizedBox to size it.
  Widget missedBusButton(VoidCallback onTap, Text text, {IconData? icon}) {
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: Colors.black12,
      foregroundColor: const Color.fromARGB(255, 40, 40, 40),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: getColor(context, ColorType.navigationStepsGray),
        ),
      ),
    );

    return SizedBox(
      height: 50.0,
      child: icon == null
          ? ElevatedButton(onPressed: onTap, style: style, child: text)
          : ElevatedButton.icon(
              onPressed: onTap,
              style: style,
              icon: Icon(icon, size: 18),
              label: text,
            ),
    ); // big beautiful pill (bbp)
  }

  // The missed bus prompt ("On the Diag-to-Diag?") lives in the manager; these
  // just redraw. It's pinned to the bottom of the sheet rather than shown as a
  // dialog, so the map stays visible and undimmed behind it.
  @override
  void displayMissedBusPrompt(MissedBusInfo info) {
    if (mounted) setState(() {});
  }

  @override
  void clearMissedBusPrompt() {
    if (mounted) setState(() {});
  }

  // The prompt's height decides how far the collapsed sheet has to grow, and we
  // only know it once it's laid out. Only setState on an actual change, or this
  // rebuilds forever.
  void _measurePrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final double height = _promptKey.currentContext?.size?.height ?? 0.0;
      if ((height - _promptHeight).abs() < 0.5) return;
      setState(() {
        _promptHeight = height;
      });
    });
  }

  Widget missedBusPromptFooter() {
    final NavigationManager manager = widget.navigationManager;
    final MissedBusInfo? prompt = manager.missedBusPrompt;
    if (prompt == null) {
      if (_promptHeight != 0.0) _measurePrompt(); // shrink the sheet back
      return const SizedBox.shrink();
    }

    _measurePrompt();

    final String? rerouteError = manager.rerouteError;

    return Container(
      key: _promptKey,
      decoration: BoxDecoration(
        color: getColor(context, ColorType.infoCardColor),
        border: Border(
          top: BorderSide(
            color: getColor(context, ColorType.navigationStepsGray),
          ),
        ),
      ),
      child: AnimatedBuilder(
        // Only the padding follows the drag: while the sheet floats, the home
        // indicator is below it, but an expanded sheet is flush with the screen
        // and the buttons would land underneath it.
        animation: _sheetController,
        builder: (context, child) => Padding(
          padding: EdgeInsets.fromLTRB(
            15,
            15,
            15,
            12 + MediaQuery.viewPaddingOf(context).bottom * _sheetProgress(),
          ),
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                RouteIcon.small(prompt.routeId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // We only know the user left the stop, not that the
                      // bus did, so ask rather than tell
                      Text(
                        "On the ${getPrettyRouteName(prompt.routeId)}?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: getColor(context, ColorType.opposite),
                        ),
                      ),
                      Text(
                        "You've left ${prompt.stopName}.",
                        style: TextStyle(
                          fontSize: 14,
                          color: getColor(
                            context,
                            ColorType.opposite,
                          ), // temporary placeholder, resolving some oddities
                        ),
                      ),
                      if (rerouteError != null)
                        Text(
                          rerouteError,
                          style: TextStyle(
                            fontSize: 14,
                            color: getColor(context, ColorType.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: missedBusButton(
                    // Ignore taps while a reroute is already underway
                    manager.isRerouting ? () {} : () => manager.reroute(),
                    Text(
                      manager.isRerouting ? "Rerouting…" : "Reroute me",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: Icons.refresh,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: missedBusButton(
                    manager.confirmBoarded,
                    const Text("I'm on it"),
                    icon: Icons.check,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // switch (widget.navigationManager.getCurrentStage()) {
    //   case NavOnBus():
    //     // Do stuff

    //   case NavWalking():
    //     // TODO: Handle this case.
    //     throw UnimplementedError();
    // }
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsGeometry.only(left: 10, right: 10, top: 70),
          child: Column(
            // Core column for vertical layout
            children: [
              // MaterialButton(
              //   color: Colors.blue.shade900,
              //   child: Text(planJourneyInProgress ? "Loading..." : "Init stages from /plan-journey"),
              //   onPressed: () async {
              //     setState(() {
              //       planJourneyInProgress = true;
              //     });
              //     try {
              //       // Try both forwards and reverse directions
              //       final fut1 = JourneyRepository.planJourney(
              //         originLat: 42.274014,
              //         originLon: -83.753664,
              //         destLat: 42.297493,
              //         destLon: -83.710782,
              //       );
              //       final fut2 = JourneyRepository.planJourney(
              //         originLat: 42.297493,
              //         originLon: -83.710782,
              //         destLat: 42.274014,
              //         destLon: -83.753664,
              //       );
              //       final journeys = (await Future.wait([fut1, fut2]))
              //         .expand((x) => x)
              //         .toList();

              //       // Pick a random journey
              //       widget.navigationManager.initFromJourney(journeys[Random().nextInt(journeys.length)]);
              //     } finally {
              //       setState(() {
              //         planJourneyInProgress = false;
              //       });
              //     }
              //   }
              // ),
              Row(
                // Top header row
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                      decoration: BoxDecoration(
                        // color: getColor(context, ColorType.mapButtonPrimary),
                        color: getColor(context, ColorType.navigationTopCardBG),
                        boxShadow: [
                          BoxShadow(
                            color: getColor(context, ColorType.mapButtonShadow),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Column(
                        children: [
                          Container(
                            // The big white card at the top

                            // margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                            padding: EdgeInsets.all(20),

                            decoration: BoxDecoration(
                              color: getColor(
                                context,
                                ColorType.navigationTopCardBG,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: getColor(
                                    context,
                                    ColorType.mapButtonShadow,
                                  ),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.pool, color: Colors.white, size: 30),
                                // Expanded(

                                // child:
                                Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        widget.navigationManager
                                            .getCurrentStage()
                                            .getTitle(),
                                      ),
                                      // Text(
                                      //   style: TextStyle(fontSize: 16, color: getColor(context, ColorType.mapButtonIcon)),
                                      //   widget.navigationManager.getCurrentStage().getSubtitle()
                                      // ),
                                    ],
                                  ),
                                ),

                                // )
                              ],
                            ),
                          ),
                          // Container(
                          //   // The smaller bottom protrusion from the big white card
                          //   padding: EdgeInsets.only(
                          //     top: 10,
                          //     bottom: 10,
                          //     left: 20,
                          //     right: 20,
                          //   ),

                          //   child: Row(
                          //     children: [
                          //       Icon(Icons.pool, size: 20, color: Colors.white),
                          //       SizedBox.square(dimension: 10),
                          //       Text(
                          //         "Then do something",
                          //         style: TextStyle(
                          //           fontWeight: FontWeight.bold,
                          //           fontSize: 18,
                          //           color: Colors.white,
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Container(
                margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                padding: EdgeInsets.all(4),

                decoration: BoxDecoration(
                  color: getColor(context, ColorType.navigationTopCardBG),
                  boxShadow: [
                    BoxShadow(
                      color: getColor(context, ColorType.mapButtonShadow),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    RouteIcon(rtid: "BB", width: 35, height: 35, fontSize: 20),
                    SizedBox.square(dimension: 10),
                    Text(
                      "You bus is arriving in mere moments",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Debug builds only: raises the missed bus prompt for the upcoming
              // bus as if you'd just left its stop, so it can be tried without
              // standing at a real one.
              if (kDebugMode)
                MaterialButton(
                  color: Colors.red.shade900,
                  child: Text("Show missed bus prompt"),
                  onPressed: () =>
                      widget.navigationManager.debugForceLeftStop(),
                ),
              // Expanded(child: SizedBox.expand()),
              // SizedBox.expand(),
              // const Spacer(),

              // VVVVVV This is the bottom bar--temporarily commenting it out to repurpose it as a DraggableScrollableSheet

              // )

              // Padding(
              //   padding: EdgeInsetsGeometry.only(left: 8),
              //   child: Text(
              //     // style: TextStyle(fontSize: 16, color: getColor(context, ColorType.primary)),
              //     "I'm told your bus is coming"
              //   ),
              // )

              //   ],
              // )
              // ),
            ],
          ),
        ),

        // TODO: Add a scrim that fades in when you drag up on the progress bar so that the background is darkened behind the DraggableScrollableSheet
        FloatingDraggableSheet(
          controller: _sheetController,
          collapsedSize:
              _collapsedSize, // Grows to make room for the missed bus prompt
          expandedSize: _sheetExpanded,
          screenCornerRadius: globalScreenBottomRadius,
          color: getColor(context, ColorType.infoCardColor),
          boxShadow: [
            BoxShadow(
              color: getColor(context, ColorType.mapButtonShadow),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          builder: (context, scrollController) {
            // The missed bus prompt sits outside the scrollable so that it
            // stays pinned to the bottom of the sheet however far it's dragged
            // up, with the steps scrolling underneath it.
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(15),
                    children: [
                      // Container(

                      // margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                      // padding: EdgeInsets.all(8),

                      // decoration: BoxDecoration(
                      //   color: getColor(context, ColorType.infoCardColor),
                      //   boxShadow: [
                      //     BoxShadow(
                      //       color: getColor(
                      //         context,
                      //         ColorType.mapButtonShadow,
                      //       ),
                      //       blurRadius: 10,
                      //       offset: Offset(0, 6),
                      //     ),
                      //   ],
                      //   borderRadius:
                      //       BorderRadius.circular(25),
                      // ),
                      // child:

                      // TODO: Figure out why the map panning is so laggy if there's a DraggableScrollableSheet on top

                      // NEXT STEPS TODO: get the steps showing inside the DraggableScrollableSheet and fix the lagging!
                      Row(
                        // Drag handle
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: getColor(
                                  context,
                                  ColorType.navigationCardProgressBG,
                                ), // TODO: Make this a real color in constants.dart
                                borderRadius: BorderRadius.circular(1000),
                              ),
                            ),
                          ),
                        ],
                      ),

                      Column(
                        children: [
                          // ClipRRect(
                          //   borderRadius: BorderRadius.circular(12),

                          // child:
                          Padding(
                            padding: EdgeInsets.only(left: 10, right: 10),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const double dotSize = 30.0;
                                const double barHeight = 15.0;
                                const double topPadding = dotSize;
                                const double bottomPadding =
                                    10.0; // Space between the bar and the ETA text below it
                                final double progressWidth =
                                    constraints.maxWidth *
                                    this.timelineInfo.activePositionPercentage;
                                final double dotLeft =
                                    progressWidth - (dotSize / 2);
                                // Centers the dot on the bar independently of the paddings above/below it
                                const double dotTop =
                                    topPadding +
                                    (barHeight / 2) -
                                    (dotSize / 2);

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: topPadding,
                                        bottom: bottomPadding,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Row(
                                              children: this
                                                  .timelineInfo
                                                  .timelineSteps
                                                  .map((item) {
                                                    return Flexible(
                                                      flex: item.estimated_time
                                                          .floor(), // Proportionally sizes to each item's time
                                                      child: Container(
                                                        height: barHeight,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: item.color,
                                                            ),
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
                                            ),
                                            Positioned(
                                              // Progress fill covering everything before the dot
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              width: progressWidth,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: maizeBusBlue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Container(
                                    //     width: dotSize,
                                    //     height: dotSize,
                                    //     decoration: const BoxDecoration(
                                    //       color: Colors.red,
                                    //       shape: BoxShape.circle
                                    //     ),
                                    //   ),
                                    Positioned(
                                      // TODO: Make this thing animate smoooooothly!
                                      left: dotLeft,
                                      top: dotTop,
                                      child: Container(
                                        width: dotSize,
                                        height: dotSize,
                                        decoration: BoxDecoration(
                                          color: getColor(
                                            context,
                                            ColorType.infoCardColor,
                                          ),
                                          border: Border.all(
                                            color: getColor(
                                              context,
                                              ColorType
                                                  .navigationCardProgressFG,
                                            ),
                                            width: 5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.only(
                              left: 10,
                              right: 10,
                              bottom: 5,
                            ),
                            child: Text(
                              navigationEtaText(
                                widget.navigationManager.arrivalTime,
                              ),
                              style: TextStyle(
                                color: getColor(
                                  context,
                                  ColorType.navigationCardFG,
                                ),
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                        // )
                      ),

                      SizedBox.square(dimension: 20.0),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.navigationManager.stageList.asMap().entries.map((
                          entry,
                        ) {
                          int index = entry.key;
                          NavigationStage stage = entry.value;

                          bool shouldRoundTopCorners =
                              (index == 0) || stage.hasRoundedCorners();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Row(
                                    children: [
                                      // ======== THIS IS THE TITLE LINE FOR EACH NAVIGATION STAGE ========
                                      Padding(
                                        padding: EdgeInsets.only(left: 10),
                                      ),

                                      Container(
                                        // Gray background behind colorful line segment
                                        width: 30,
                                        height: 50,
                                        decoration: (index != 0)
                                            ? BoxDecoration(
                                                color: getColor(
                                                  context,
                                                  ColorType.navigationStepsGray,
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  bottomLeft:
                                                      (index ==
                                                          widget
                                                                  .navigationManager
                                                                  .stageList
                                                                  .length -
                                                              1)
                                                      ? Radius.circular(20)
                                                      : Radius.circular(0),
                                                  bottomRight:
                                                      (index ==
                                                          widget
                                                                  .navigationManager
                                                                  .stageList
                                                                  .length -
                                                              1)
                                                      ? Radius.circular(20)
                                                      : Radius.circular(0),
                                                ),
                                              )
                                            : null,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: stage.getColor(),
                                            borderRadius: BorderRadius.only(
                                              topLeft: (shouldRoundTopCorners)
                                                  ? Radius.circular(20)
                                                  : Radius.circular(0),
                                              topRight: (shouldRoundTopCorners)
                                                  ? Radius.circular(20)
                                                  : Radius.circular(0),
                                              // bottomLeft: Radius.circular(20),
                                              // bottomRight: Radius.circular(20)
                                              bottomLeft:
                                                  (index ==
                                                      widget
                                                              .navigationManager
                                                              .stageList
                                                              .length -
                                                          1)
                                                  ? Radius.circular(20)
                                                  : Radius.circular(0),
                                              bottomRight:
                                                  (index ==
                                                      widget
                                                              .navigationManager
                                                              .stageList
                                                              .length -
                                                          1)
                                                  ? Radius.circular(20)
                                                  : Radius.circular(0),
                                            ),
                                          ),
                                        ),
                                      ),

                                      Padding(
                                        padding: EdgeInsets.only(left: 15),
                                      ),
                                      Text(
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        stage.getFixedTitle(),
                                      ),
                                      // Spacer(),
                                      Container(width: 40),
                                      // Text(stage.g())
                                    ],
                                  ),

                                  stage is NavOnBus
                                      ? Padding(
                                          padding: EdgeInsets.only(left: 1),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(9999),
                                              border: Border.all(
                                                color: getColor(
                                                  context,
                                                  ColorType.infoCardColor,
                                                ),
                                                width: 4,
                                              ),
                                              // boxShadow: [
                                              //   BoxShadow(
                                              //     blurRadius: 3,
                                              //     spreadRadius: 0,
                                              //     color: Color(0x88000000)
                                              //   )
                                              // ]
                                            ),
                                            child: RouteIcon(
                                              rtid: stage.state.rt,
                                              width: 40,
                                              height: 40,
                                              fontSize: 20,
                                            ),
                                          ),
                                        )
                                      // Text(stage.state.rt)
                                      : SizedBox.shrink(),

                                  // Text("HIIIII"),
                                ],
                              ),

                              ...stage.getSteps().asMap().entries.map((entry) {
                                int sub_index = entry.key;
                                NavigationStageStep step = entry.value;
                                // NEXT STEPS TODO: get live location showing on the step list

                                bool shouldRoundBottomCorners = false;

                                if (index ==
                                        widget
                                                .navigationManager
                                                .stageList
                                                .length -
                                            1 &&
                                    sub_index == stage.getSteps().length - 1) {
                                  shouldRoundBottomCorners = true;
                                }

                                if (stage.hasRoundedCorners() &&
                                    sub_index == stage.getSteps().length - 1) {
                                  shouldRoundBottomCorners = true;
                                }

                                return Stack(
                                  children: [
                                    Positioned(
                                      left: 10,
                                      top: 0,
                                      bottom: 0,
                                      width: 30,
                                      child: Container(
                                        // Gray background behind colorful line segment
                                        width: 30,
                                        // height: 40,
                                        decoration:
                                            (index !=
                                                widget
                                                        .navigationManager
                                                        .stageList
                                                        .length -
                                                    1)
                                            ? BoxDecoration(
                                                // Only show the gray background if the box shouldn't have a rounded bottom (i.e. isn't at the end of the stage list)
                                                color: getColor(
                                                  context,
                                                  ColorType.navigationStepsGray,
                                                ),
                                              )
                                            : null,
                                        child: Container(
                                          // Colorful line segment
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: step.getColor(),
                                            borderRadius: BorderRadius.only(
                                              bottomLeft:
                                                  (shouldRoundBottomCorners)
                                                  ? Radius.circular(20)
                                                  : Radius.zero,
                                              bottomRight:
                                                  (shouldRoundBottomCorners)
                                                  ? Radius.circular(20)
                                                  : Radius.zero,
                                            ),
                                          ),

                                          child: Container(
                                            // Inside dot or dash
                                            width:
                                                step.lineType == LineType.Dotted
                                                ? ((sub_index ==
                                                          stage
                                                                  .getSteps()
                                                                  .length -
                                                              1)
                                                      ? 20
                                                      : 10)
                                                : 4,
                                            height:
                                                step.lineType == LineType.Dotted
                                                ? ((sub_index ==
                                                          stage
                                                                  .getSteps()
                                                                  .length -
                                                              1)
                                                      ? 20
                                                      : 10)
                                                : 16,
                                            // color: Colors.white,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(100),
                                              ),
                                            ),
                                            // color: Colors.white
                                          ),
                                        ),
                                      ),
                                    ),

                                    Padding(
                                      padding: EdgeInsetsGeometry.only(
                                        top: 10,
                                        bottom: 10,
                                        left: 55,
                                      ),
                                      child: Row(
                                        children: [
                                          // Padding(padding: EdgeInsets.only(left: 20)),

                                          // Padding(padding: EdgeInsets.only(left: 20)),
                                          Expanded(
                                            child: Text(step.getTitle()),
                                          ),

                                          // // Spacer(),
                                          // Container(width: 40),
                                          Text(step.getTime()),
                                        ],
                                      ),
                                    ),
                                  ],
                                );

                                // return Row(
                                //   children: [
                                //     Padding(padding: EdgeInsets.only(left: 20)),
                                //     Container( // Gray background behind colorful line segment
                                //       width: 30,
                                //       height: 40,
                                //       decoration: (index != widget.navigationManager.stageList.length - 1) ? BoxDecoration(
                                //         // Only show the gray background if the box shouldn't have a rounded bottom (i.e. isn't at the end of the stage list)
                                //         color: getColor(context, ColorType.navigationStepsGray)
                                //       ) : null,
                                //       child: Container( // Colorful line segment
                                //         alignment: Alignment.center,
                                //         decoration: BoxDecoration(
                                //           color: step.getColor(),
                                //           borderRadius: BorderRadius.only(
                                //             bottomLeft: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero,
                                //             bottomRight: (shouldRoundBottomCorners) ? Radius.circular(20) : Radius.zero
                                //           )
                                //         ),

                                //         child: Container( // Inside dot or dash
                                //           width: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 4,
                                //           height: step.lineType == LineType.Dotted ? ((sub_index == stage.getSteps().length - 1) ? 20 : 10) : 16,
                                //           // color: Colors.white,
                                //           decoration: BoxDecoration(
                                //             color: Colors.white,
                                //             borderRadius: BorderRadius.all(Radius.circular(100))
                                //           ),
                                //           // color: Colors.white
                                //         )
                                //       ),
                                //     ),
                                //     Padding(padding: EdgeInsets.only(left: 20)),
                                //     Expanded(
                                //       child: Text(step.getTitle() + step.getTitle()),
                                //     ),

                                //     // // Spacer(),
                                //     // Container(width: 40),
                                //     Text(step.getTime())
                                //   ]
                                // );
                              }).toList(),
                            ],
                          );
                          // return Text(stage.getTitle());
                        }).toList(),
                      ),

                      Padding(
                        padding: EdgeInsets.only(top: 15, left: 10, right: 10),
                        child: missedBusButton(
                          // Routes through the map screen's PopScope, so this does exactly
                          // what the Android system back button does (closes this overlay)
                          () => Navigator.maybePop(context),
                          const Text("Exit navigation"),
                        ),
                      ),

                      // )
                    ],
                  ),
                ),
                missedBusPromptFooter(),
              ],
            );
          },
        ),
      ],
    );
  }
}

// QUESTION: Should navigation_manager

// FUTURE TODO: Add "Connection lost"/"GPS not very accurate" banners to alert the user of those things
// Some sort of live rotating compass that points to the end of the segment (i.e. if you're walking it replaces the icon and rotates)
