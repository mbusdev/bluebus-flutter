import '../constants.dart';
import 'package:flutter/material.dart';

class POISheet extends StatefulWidget {
  final String name;

  const POISheet({
    Key? key,
    required this.name
  }) : super(key: key);
  
  @override
  State<POISheet> createState() => _POISheetState();
}

class _POISheetState extends State<POISheet> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20,),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.name,
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 40,
                height: 0
              ),
            ),
          ),
      
          SizedBox(width: double.infinity, height: 75,),
        ],
      )
    );
  }
}