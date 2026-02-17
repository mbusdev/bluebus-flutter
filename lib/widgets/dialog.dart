import 'package:bluebus/constants.dart';
import 'package:flutter/material.dart';

/// A wrapper for showDialog that applies a consistent 
/// maizebus style to all dialogs in the app.
Future<T?> showMaizebusOKDialog<T>({
  required BuildContext contextIn,
  Widget? title,
  Widget? content,
}) {
  return showDialog<T>(
    context: contextIn,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        backgroundColor: getColor(context, ColorType.background),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        titleTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        contentTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 16,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actionsAlignment: MainAxisAlignment.end,
        
        title: title,
        content: content,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                backgroundColor: getColor(context, ColorType.mapButtonPrimary),
                foregroundColor: getColor(context, ColorType.mapButtonIcon),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Rounded corners
                ),
                elevation: 2

              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(
                  color: getColor(context, ColorType.mapButtonIcon),
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                ),
              )
            ),
          ),
        ],
      );
    },
  );
}

/// guess what this one does 
Future<T?> showUndismissableMaizebusDialog<T>({
  required BuildContext contextIn,
  Widget? title,
  Widget? content,
}) {
  return showDialog<T>(
    context: contextIn,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        backgroundColor: getColor(context, ColorType.background),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        titleTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        contentTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 16,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actionsAlignment: MainAxisAlignment.end,
        
        title: title,
        content: content,
        actions: [],
      );
    },
  );
}