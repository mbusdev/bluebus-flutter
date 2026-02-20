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
          borderRadius: BorderRadius.circular(36.0),
        ),
        backgroundColor: getColor(context, ColorType.background),
        titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        titleTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Urbanist',
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        contentTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 18,
          fontFamily: 'Urbanist',
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        actionsAlignment: MainAxisAlignment.end,
        
        title: title,
        content: content,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                backgroundColor: getColor(context, ColorType.importantButtonBackground),
                foregroundColor: getColor(context, ColorType.importantButtonText),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Rounded corners
                ),
                elevation: 0

              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(
                  color: getColor(context, ColorType.importantButtonText),
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Urbanist',
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
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        titleTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Urbanist',
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        contentTextStyle: TextStyle(
          color: getColor(context, ColorType.opposite),
          fontSize: 18,
          fontFamily: 'Urbanist',
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        actionsAlignment: MainAxisAlignment.end,
        
        title: title,
        content: content,
        actions: [],
      );
    },
  );
}