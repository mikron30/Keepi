import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreference {
  ThemePreference._();

  static const _darkModeKey = 'dark_mode';

  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    if (!preferences.containsKey(_darkModeKey)) {
      notifier.value = ThemeMode.system;
      return;
    }

    notifier.value = preferences.getBool(_darkModeKey) == true
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool enabled) async {
    notifier.value = enabled ? ThemeMode.dark : ThemeMode.light;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, enabled);
  }
}
