import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A [DraggableScrollableSheet] that floats above the bottom of the screen while
/// it is collapsed and grows edge to edge as it is dragged up, similar to the
/// Apple Maps bottom sheet.
///
/// While collapsed the sheet is inset by [inset] on the left, right and bottom.
/// The inset shrinks to zero as the sheet is dragged towards [expandedSize], so
/// a fully expanded sheet sits flush against the edges of the screen.
///
/// The corners follow the physical screen corners: a sheet inset by `i` is
/// rounded by [screenCornerRadius] `- i`, so it stays concentric with the screen
/// while floating and matches it exactly once the inset reaches zero. Pass the
/// value from the `screen_corner_radius` package as [screenCornerRadius].
///
/// The bottom corners hug the screen, so they follow it all the way down to
/// square on a device that reports no radius. The top corners aren't against an
/// edge: they're currently held at a fixed [topRadius], but see the commented
/// out line in [build] to make them follow the screen too (never dropping below
/// [minRadius]).
class FloatingDraggableSheet extends StatefulWidget {
  const FloatingDraggableSheet({
    super.key,
    required this.builder,
    required this.color,
    this.collapsedSize = 0.12,
    this.expandedSize = 0.85,
    this.inset = 10,
    this.screenCornerRadius = 0,
    this.minRadius = 25,
    this.topRadius = 25,
    this.boxShadow = const [],
  });

  /// Builds the sheet's contents. The [ScrollController] must be handed to a
  /// scrollable descendant, exactly like [DraggableScrollableSheet.builder].
  final Widget Function(BuildContext context, ScrollController scrollController)
      builder;

  /// Background color of the sheet. Contents are clipped to its rounded corners.
  final Color color;

  /// Height of the visible (floating) sheet as a fraction of the available
  /// height, excluding the [inset] below it.
  final double collapsedSize;

  /// Height of the fully expanded sheet as a fraction of the available height.
  final double expandedSize;

  /// Gap between the collapsed sheet and the left, right and bottom edges.
  final double inset;

  /// Corner radius of the physical screen, used to keep the sheet's corners
  /// concentric with it.
  final double screenCornerRadius;

  /// Smallest radius the sheet rounds its corners by, for screens whose radius
  /// is too small to derive a concentric one from. The bottom corners ignore
  /// this once they are flush with the screen edge, so a square-cornered screen
  /// gets square bottom corners.
  final double minRadius;

  /// Corner radius of the top of the sheet, in every state.
  final double topRadius;

  final List<BoxShadow> boxShadow;

  @override
  State<FloatingDraggableSheet> createState() => _FloatingDraggableSheetState();
}

class _FloatingDraggableSheetState extends State<FloatingDraggableSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The sheet's box always reaches the bottom of the screen and the inset
        // is drawn inside of it, so the collapsed box has to be taller by the
        // inset for the visible part to still be [collapsedSize] tall.
        final double minSize = (widget.collapsedSize +
                widget.inset / constraints.maxHeight)
            .clamp(0.0, widget.expandedSize);

        return DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: minSize,
          minChildSize: minSize,
          maxChildSize: widget.expandedSize,
          snap: true,
          builder: (context, scrollController) {
            // DraggableScrollableSheet builds this only once, so the sheet's
            // chrome subscribes to the controller itself and the contents are
            // passed through untouched (and unrebuilt) as [child].
            return AnimatedBuilder(
              animation: _controller,
              child: widget.builder(context, scrollController),
              builder: (context, child) {
                final double size =
                    _controller.isAttached ? _controller.size : minSize;
                // 0 while collapsed, 1 once fully expanded.
                final double t = ((size - minSize) /
                        max(widget.expandedSize - minSize, 0.0001))
                    .clamp(0.0, 1.0);
                final double inset = widget.inset * (1 - t);

                // Concentric with the screen: the further in the sheet sits,
                // the tighter its corners.
                final double radius = max(
                  widget.screenCornerRadius - inset,
                  widget.minRadius,
                );

                return Padding(
                  padding: EdgeInsets.only(
                    left: inset,
                    right: inset,
                    bottom: inset,
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: widget.color,
                      boxShadow: widget.boxShadow,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(widget.topRadius),
                        // top: Radius.circular(radius), // uncomment to make the top corners match the screen as well
                        // Unlike the top, the bottom is up against the screen
                        // edge once expanded, so it follows the screen exactly
                        // instead of stopping at [minRadius].
                        bottom: Radius.circular(
                          lerpDouble(radius, widget.screenCornerRadius, t)!,
                        ),
                      ),
                    ),
                    child: child,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
