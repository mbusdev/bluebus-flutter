import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeStyle {
  system, light, dark,
}

class ThemeProvider extends ChangeNotifier {
  // Maps from each ThemeStyle enum to the ThemeData object
  // - ThemeStyle.system is updated when the system theme changes
  static Map<ThemeStyle, ThemeData> _themeDataMap = {
    ThemeStyle.system: SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? darkMode : lightMode,
    ThemeStyle.light: lightMode,
    ThemeStyle.dark: darkMode,
  };

  ThemeStyle _theme = ThemeStyle.light;
  ThemeStyle get theme => _theme;

  ThemeData getThemeData() {
    return _themeDataMap[_theme]!;
  }

  // listen for system theme changes
  void onSystemThemeUpdate(BuildContext context) {
    var window = View.of(context).platformDispatcher;

    // When the system theme changes, change the _themeDataMap for the system theme accordingly
    window.onPlatformBrightnessChanged = () {
      _themeDataMap[ThemeStyle.system] = window.platformBrightness == Brightness.dark ? darkMode : lightMode;
      
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

  // stores the index in the ThemeSystem enum of the current theme in userdata
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

  // toggles between dark and light mode
  void swap(BuildContext context) {
    _theme = Theme.of(context).brightness == Brightness.dark ? ThemeStyle.light : ThemeStyle.dark;
    saveTheme();
    notifyListeners();
  }
}