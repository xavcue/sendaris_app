import 'package:flutter/material.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggle(Brightness currentBrightness) {
    _themeMode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;

    notifyListeners();
  }

  void useSystemMode() {
    if (_themeMode == ThemeMode.system) {
      return;
    }

    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}
