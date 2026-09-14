import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFF1E293B); // Slate 800
  static const Color accentColor = Color(0xFF0284C7);  // Sky 600
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color dangerColor = Color(0xFFEF4444);  // Rose 500

  static ThemeData lightTheme(String languageCode) {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = languageCode == 'ar'
        ? GoogleFonts.cairoTextTheme(baseTextTheme)
        : GoogleFonts.interTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: dangerColor,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: const CardThemeData(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  static ThemeData darkTheme(String languageCode) {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = languageCode == 'ar'
        ? GoogleFonts.cairoTextTheme(baseTextTheme)
        : GoogleFonts.interTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: const Color(0xFF38BDF8),
        secondary: accentColor,
        error: dangerColor,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF334155)),
        ),
        color: Color(0xFF1E293B),
      ),
    );
  }
}
