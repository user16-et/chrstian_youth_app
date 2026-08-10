import 'package:flutter/material.dart';

/// App-wide theme mode. Any screen (e.g. the Bible reader's day/night shortcut)
/// can flip it without threading callbacks through the widget tree; `app.dart`
/// listens to [mode], rebuilds, and persists the change.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// Flip between light and dark (a system default counts as light → dark).
  void toggle() {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
