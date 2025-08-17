import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  Rx<ThemeMode> themeMode = ThemeMode.system.obs; // Default to system theme

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromPreferences(); 
  }

  bool get isDarkMode {
    if (themeMode.value == ThemeMode.system) {
      // Use system theme
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }

  void toggleTheme() async {
    if (themeMode.value == ThemeMode.light ||
        themeMode.value == ThemeMode.system) {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.light;
    }

    Get.changeThemeMode(themeMode.value);
    await _saveThemeToPreferences(); // Save the new theme
  }

  Future<void> _saveThemeToPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String themeString = themeMode.value
        .toString()
        .split('.')
        .last; // 'light', 'dark', or 'system'
    await prefs.setString(
        'themeMode', themeString); // Save themeMode as a string
  }

  Future<void> initializeTheme() async {
    await _loadThemeFromPreferences(); // Call the private method
  }

  Future<void> _loadThemeFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeString = prefs.getString('themeMode');

    if (themeString == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (themeString == 'light') {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.system;
    }

    Get.changeThemeMode(themeMode.value); // Apply the loaded theme
  }
}
