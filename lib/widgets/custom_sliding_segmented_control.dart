import 'package:flutter/material.dart';

// custom widget that lets you select between multiple segments by sliding OR tapping and looks nice
class MaizebusSlidingSegmentedControl extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<int> onSelectionChanged;
  final int initialIndex;
  final Color backgroundColor;
  final Color thumbColor;
  final TextStyle? labelStyle;
  final TextStyle? selectedLabelStyle;
  final double height;
  final double width;

  const MaizebusSlidingSegmentedControl({
    Key? key,
    required this.labels,
    required this.onSelectionChanged,
    this.initialIndex = 0,
    this.backgroundColor = const Color(0xFFE0E0E0), // Default grey
    this.thumbColor = Colors.white,
    this.labelStyle,
    this.selectedLabelStyle,
    this.height = 50,
    this.width = 300,
  }) : super(key: key);

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
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the width of a single segment based on total width
          double segmentWidth = constraints.maxWidth / widget.labels.length;

          return GestureDetector(
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
                      color: widget.thumbColor,
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
                                  const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 14,
                                  ))
                              : (widget.labelStyle ??
                                  TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  )),
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