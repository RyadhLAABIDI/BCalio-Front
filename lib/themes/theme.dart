import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Couleurs basées sur le logo
const kLightPrimaryColor = Color(0xFF89C6C9); // Bleu sarcelle métallique
const kDarkPrimaryColor = Color(0xFFC46535); // Orange cuivré
const kDarkBgColor = Color.fromARGB(255, 0, 8, 8); // Bleu nuit profond pour mode sombre
const kLightBgColor = Color(0xFFF5F7FA); // Gris perle doux pour mode clair
const kAccentColor = Color(0xFF327E88); // Turquoise ombré
const kShadowColor = Color(0xFF3C3C3C); // Gris acier foncé
const kHighlightColor = Color(0xFFF1EEE8); // Blanc cassé
const kBackgroundAccent = Color(0xFF943A1B); // Rouge brun

class AppThemes {
  // Thème clair
  static final lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: kLightBgColor,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: kLightPrimaryColor,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: kLightPrimaryColor,
      primary: kLightPrimaryColor,
      secondary: kAccentColor,
      surface: kLightBgColor,
      onSurface: kShadowColor,
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.poppins(
        color: kShadowColor,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.poppins(
        color: kShadowColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(
        color: kShadowColor.withOpacity(0.8),
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: kShadowColor.withOpacity(0.6),
        fontSize: 14,
      ),
      labelLarge: GoogleFonts.poppins(
        color: kLightPrimaryColor,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kLightPrimaryColor,
        foregroundColor: kHighlightColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kHighlightColor.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kLightPrimaryColor, width: 2),
      ),
      hintStyle: GoogleFonts.poppins(color: kShadowColor.withOpacity(0.5)),
    ),
    iconTheme: const IconThemeData(color: kLightPrimaryColor),
  );

  // Thème sombre
  static final darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: kDarkBgColor,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: kHighlightColor,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: kDarkPrimaryColor,
      primary: kDarkPrimaryColor,
      secondary: kAccentColor,
      surface: kDarkBgColor,
      onSurface: kHighlightColor,
    ),
    textTheme: TextTheme(
      titleLarge: GoogleFonts.poppins(
        color: kHighlightColor,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.poppins(
        color: kHighlightColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(
        color: kHighlightColor.withOpacity(0.8),
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: kHighlightColor.withOpacity(0.6),
        fontSize: 14,
      ),
      labelLarge: GoogleFonts.poppins(
        color: kDarkPrimaryColor,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kDarkPrimaryColor,
        foregroundColor: kHighlightColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kHighlightColor.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kDarkPrimaryColor, width: 2),
      ),
      hintStyle: GoogleFonts.poppins(color: kHighlightColor.withOpacity(0.5)),
    ),
    iconTheme: const IconThemeData(color: kDarkPrimaryColor),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kDarkPrimaryColor.withOpacity(0.9),
      contentTextStyle: GoogleFonts.poppins(color: kHighlightColor),
    ),
  );
}