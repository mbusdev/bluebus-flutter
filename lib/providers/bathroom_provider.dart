import 'package:flutter/material.dart';
import 'package:bluebus/constants.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BathroomPreference {
  notchosen, womens, mens, inclusive
}

class BathroomProvider extends ChangeNotifier {
  BathroomPreference _preference = BathroomPreference.notchosen;
  BathroomPreference get preference => _preference;

    // save and load
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _preference = BathroomPreference.values[prefs.getInt('bathroomPref') ?? 0]; // gets enum value at index
    notifyListeners();
  }

  // stores the index in the preference enum of the current theme in userdata
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("bathroomPref", _preference.index); // stores preference enum index
  }
  
  void set(BathroomPreference pref) {
    if (_preference == pref) return;

    _preference = pref;
    save();
    notifyListeners();
  }
}