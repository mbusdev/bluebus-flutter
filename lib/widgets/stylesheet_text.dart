import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';

class StylesheetText extends StatelessWidget {
  const StylesheetText({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text("Modal Header", style: getTextStyle(TextType.modalHeader, color)),
        Text("maizebus", style: getTextStyle(TextType.logo, color)),
        Text("Bold\nBold", style: getTextStyle(TextType.bold, color)),
        Text("Normal\nNormal", style: getTextStyle(TextType.normal, color)),
        Text("Small\nSmall", style: getTextStyle(TextType.small, color)),
        Text(
          "Section Header",
          style: getTextStyle(TextType.sectionHeader, color),
        ),
      ],
    );
  }
}
