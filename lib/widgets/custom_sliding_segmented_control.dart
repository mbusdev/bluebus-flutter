import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';
// custom widget that lets you select between multiple segments by sliding OR tapping and looks nice
class MaizebusSlidingSegmentedControl extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<int> onSelectionChanged;
  final int selectedIndex; 
  final ColorType backgroundColor;
  final ColorType thumbColor;
  final TextStyle? labelStyle;
  final TextStyle? selectedLabelStyle;
  final double height;
  final double width;
  final List<BoxShadow>? shadows;

  const MaizebusSlidingSegmentedControl({
    super.key,
    required this.labels,
    required this.onSelectionChanged,
    this.selectedIndex = 0,
    this.backgroundColor = ColorType.sliderBackground,
    this.thumbColor = ColorType.sliderButton, //slider bg color
    this.labelStyle,
    this.selectedLabelStyle,
    this.height = 50,
    this.width = 300,
    this.shadows,
  });

  @override
  State<MaizebusSlidingSegmentedControl> createState() =>
      _MaizebusSlidingSegmentedControlState();
}

class _MaizebusSlidingSegmentedControlState
    extends State<MaizebusSlidingSegmentedControl> {
  late int _selectedIndex;
  

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  // This listens for changes from the parent (e.g., PageView swipe)
  // so the widget can stay in sync with external state changes.
  @override
  void didUpdateWidget(covariant MaizebusSlidingSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      setState(() {
        _selectedIndex = widget.selectedIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: getColor(context, widget.backgroundColor),
        borderRadius: BorderRadius.circular(25),
        boxShadow: widget.shadows,
        
        
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the width of a single segment based on total width
          double segmentWidth = constraints.maxWidth / widget.labels.length;

          return GestureDetector(
            behavior: HitTestBehavior.opaque, 
            
            // Tap logic
            onTapUp: (details) {
              int newIndex = (details.localPosition.dx / segmentWidth).floor();
              _updateSelection(newIndex);
            },
            // Drag logic
            onHorizontalDragUpdate: (details) {
              int newIndex = (details.localPosition.dx / segmentWidth).floor();
              _updateSelection(newIndex);
            },
            child: Stack(
              children: [
                //inner shadow?
                
                // the animated thumb
                AnimatedAlign(
                  alignment: Alignment(
                    // Map index (0, 1...) to Alignment (-1.0 to 1.0)
                    -1.0 + (_selectedIndex * 2 / (widget.labels.length - 1)),
                    0.0,
                  ),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: segmentWidth,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    decoration: BoxDecoration(
                      color: getColor(context, widget.thumbColor),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ),
                // text labels
                Row(
                  children: widget.labels.asMap().entries.map((entry) {
                    int idx = entry.key;
                    String label = entry.value;
                    bool isSelected = _selectedIndex == idx;

                    return Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: isSelected
                              ? (widget.selectedLabelStyle ??
                                  getTextStyle(TextType.bold, getColor(context, ColorType.opposite))
                                )
                              : (widget.labelStyle ??
                                  getTextStyle(TextType.normal, getColor(context, ColorType.opposite))
                                ),
                          child: Text(label),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateSelection(int newIndex) {
    // Ensure we don't crash if dragging outside bounds
    int clampedIndex = newIndex.clamp(0, widget.labels.length - 1);

    if (clampedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = clampedIndex;
      });
      widget.onSelectionChanged(clampedIndex);
    }
  }
}