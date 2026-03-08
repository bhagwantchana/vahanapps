import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E293B);
  static const Color secondary = Color(0xFF64748B);
  static const Color accent = Color(0xFF3B82F6);
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF94A3B8);
  static const Color lightGrey = Color(0xFFE2E8F0);

  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color orangeLight = Color(0xFFFEF3C7);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color blueLight = Color(0xFFDBEAFE);
}

class Themes {
  static ThemeData defaultTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.scaffoldBackground,
    primaryColor: AppColors.accent,

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.scaffoldBackground,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.primary),
      titleTextStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),

    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.cardBackground,
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.lightGrey, width: 1),
      ),
    ),
  );
}

class TextStyles {
  static const TextStyle heading1 = TextStyle(
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    fontSize: 48,
  );

  static const TextStyle heading2 = TextStyle(
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    fontSize: 32,
  );

  static const TextStyle heading3 = TextStyle(
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    fontSize: 24,
  );

  static const TextStyle body1 = TextStyle(
    fontWeight: FontWeight.normal,
    color: AppColors.primary,
    fontSize: 18,
  );

  static const TextStyle body2 = TextStyle(
    fontWeight: FontWeight.normal,
    color: AppColors.primary,
    fontSize: 16,
  );
}
