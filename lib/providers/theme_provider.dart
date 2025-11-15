import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeStyle {
  system, light, dark,
}

Map<ThemeStyle, ThemeData> themeDataMap = {
  ThemeStyle.system: SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? darkMode : lightMode,
  ThemeStyle.light: lightMode,
  ThemeStyle.dark: darkMode,
};

class ThemeProvider extends ChangeNotifier {
  ThemeStyle _theme = ThemeStyle.light;

  ThemeStyle get theme => _theme;

  ThemeData getThemeData() {
    return themeDataMap[_theme]!;
  }

  // listen for system theme changes
  void onSystemThemeUpdate(BuildContext context) {
    var window = View.of(context).platformDispatcher;

    window.onPlatformBrightnessChanged = () {
      themeDataMap[ThemeStyle.system] = window.platformBrightness == Brightness.dark ? darkMode : lightMode;
      
      if (_theme == ThemeStyle.system) {
        notifyListeners();
      }
    };
  }

  // save and load
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _theme = ThemeStyle.values[prefs.getInt('theme') ?? 0]; // gets enum value at index
    notifyListeners();
  }

  Future<void> saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("theme", _theme.index); // stores theme enum index
  }

  // setters
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