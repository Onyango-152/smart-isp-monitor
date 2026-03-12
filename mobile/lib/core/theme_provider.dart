import 'package:flutter/material.dart';

/// ThemeProvider holds the single source of truth for the current theme mode.
/// Registered at the top of the widget tree in main.dart so any screen can
/// read or toggle it via `context.read<ThemeProvider>()`.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get themeMode  => _mode;
  bool      get isDarkMode => _mode == ThemeMode.dark;

  void toggleDarkMode() {
    _mode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _mode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
