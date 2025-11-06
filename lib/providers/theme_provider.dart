import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeStyle {
  dark, light
}

Map<ThemeStyle, ThemeData> themeDataMap = {
  ThemeStyle.dark: darkMode,
  ThemeStyle.light: lightMode
};

class ThemeProvider extends ChangeNotifier {
  ThemeStyle _theme = ThemeStyle.light;

  ThemeStyle get theme => _theme;

  // save and load
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = ThemeStyle.values[prefs.getInt('theme') ?? 1]; // gets enum value at index
    notifyListeners();
  }

  Future<void> saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("theme", _theme.index); // stores theme enum index
  }

  void setTheme(ThemeStyle theme) {
    if (_theme == theme) return;

    _theme = theme;
    saveTheme();
    notifyListeners();
  }

  void swap() {
    _theme = _theme == ThemeStyle.dark ? ThemeStyle.light : ThemeStyle.dark;
    saveTheme();
    notifyListeners();
  }
}