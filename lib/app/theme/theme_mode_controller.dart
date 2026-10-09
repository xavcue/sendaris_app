import 'package:flutter/material.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();
  }

  void toggle(Brightness currentBrightness) {
    setThemeMode(
      currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void useSystemMode() {
    setThemeMode(ThemeMode.system);
  }
}
