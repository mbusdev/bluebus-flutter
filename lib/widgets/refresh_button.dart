import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';

/// Can also be used as purely a loading spinner by having loading = true and onTap = null
class RefreshButton extends StatelessWidget {
  const RefreshButton({
    super.key,
    required this.loading,
    this.onTap,
    this.refreshIconColor,
  });

  final bool loading;
  final Function()? onTap;
  final Color? refreshIconColor;

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      width: 30,
      height: 30,
      child: loading
          ? Align(
              // For some bizarre reason this is required to get the CircularProgressIndicator to conform to the size of the ConstrainedBox
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: 15, height: 15),
                child: CircularProgressIndicator(
                  color: getColor(context, ColorType.opposite),
                  strokeWidth: 2.5,
                ),
              ),
            )
          : Icon(Icons.refresh, color: refreshIconColor),
    );
    if (onTap != null) {
      return InkWell(
        customBorder: CircleBorder(),
        onTap: () {
          onTap!.call();
        },
        child: inner,
      );
    } else {
      return inner;
    }
  }
}
