import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary & Secondary
  static const Color primary = Color(0xFF0A3D62);
  static const Color secondary = Color(0xFF2ECC71);
  static const Color alert = Color(0xFFF39C12);

  // Backgrounds
  static const Color bgLight = Color(0xFFF5F5F7);
  static const Color bgDark = Color(0xFF0B0E11);

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF94A3B8);
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color darkGrey = Color(0xFF1E293B);

  // Status Colors
  static const Color moving = Color(0xFF2ECC71);
  static const Color idle = Color(0xFFF39C12);
  static const Color offline = Color(0xFFE74C3C);

  static const Color accent = Color(0xFF3B82F6);
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color orangeLight = Color(0xFFFEF3C7);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color blueLight = Color(0xFFDBEAFE);
}

class AppTheme {
  static const Color primaryBlue = Color(0xFF2D5C88);
  static const Color primaryGreen = Color(0xFF7BC043);
  static const Color background = Color(0xFFF5F7FA);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryGreen,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: Colors.black12,
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 1,
        shadowColor: Colors.black12,
        centerTitle: true,
      ),
    );
  }

  // Dark theme — adapts Scaffold, AppBar, Card, and text colours via
  // ThemeData. Note: many widgets in this app still use hardcoded
  // `Colors.white` / `Color(0xFF...)` for backgrounds, so those will stay
  // light even with dark mode enabled. The toggle is wired and functional;
  // migrate widgets to `Theme.of(context).colorScheme.*` incrementally as
  // you touch them. Critical chrome (AppBar, Drawer, Scaffold base) does
  // adapt today.
  static const Color darkBackground = Color(0xFF0B0E11);
  static const Color darkSurface = Color(0xFF1A1F25);
  static const Color darkPrimary = Color(0xFF4A8BC4);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: primaryGreen,
        surface: darkSurface,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: Colors.black54,
        color: darkSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black54,
        centerTitle: true,
      ),
    );
  }
}
