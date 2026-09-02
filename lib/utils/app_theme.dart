import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  // Light mode surfaces
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightCard = Colors.white;

  // Dark mode surfaces — dark neutral, not pure black (easier on the eyes,
  // and keeps the green gradient headers from looking harsh against true black)
  static const Color darkBackground = Color(0xFF121417);
  static const Color darkCard = Color(0xFF1C1F23);
  static const Color darkCardAlt = Color(0xFF23262B);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Amiri',
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: Brightness.light,
      ),
      cardColor: AppColors.lightCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme().apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Amiri',
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: Brightness.dark,
      ),
      cardColor: AppColors.darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme().apply(
        bodyColor: Colors.white.withOpacity(0.92),
        displayColor: Colors.white,
      ),
    );
  }
}
