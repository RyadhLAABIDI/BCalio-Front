import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends GetxController {
  // Observables
  var selectedLocale = const Locale('en', 'US').obs;

  // Keys for SharedPreferences
  static const String languageKey = 'language';
  static const String countryKey = 'country';

  @override
  void onInit() {
    super.onInit();
    initializeLanguage(); // Ensure preferences are loaded at startup
  }

  // Initialize the language from SharedPreferences
  Future<void> initializeLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(languageKey) ?? 'en';
    final savedCountryCode = prefs.getString(countryKey) ?? 'US';
    final locale = Locale(savedLanguageCode, savedCountryCode);

    selectedLocale.value = locale;
    Get.updateLocale(locale); // Apply the saved locale
  }

  // Change the language and save it to SharedPreferences
  Future<void> changeLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(languageKey, locale.languageCode);
    await prefs.setString(countryKey, locale.countryCode ?? '');

    selectedLocale.value = locale;
    Get.updateLocale(locale); // Apply the new locale
  }
}
