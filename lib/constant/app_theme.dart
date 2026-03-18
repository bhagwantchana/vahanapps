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
}

class Themes {
  static ThemeData lightTheme = _buildTheme(Brightness.light);
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardColor = isDark ? AppColors.darkGrey : AppColors.white;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.alert,
        surface: cardColor,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.white : AppColors.primary,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.white : AppColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: AppColors.primary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // Keeping defaultTheme for backwards compatibility if needed, but we'll use light/dark
  static ThemeData get defaultTheme => lightTheme;
}
