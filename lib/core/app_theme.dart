import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors - Changed from Golden to Blue
  static const Color primary = Color(0xFF1E88E5); // Blue
  static const Color primaryVariant = Color(0xFF0D47A1); // Darker Blue
  
  // Neutral Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Color(0xFFF5F7FA); // Light grey for backgrounds
  static const Color darkGrey = Color(0xFF1E1E1E); // Dark grey for surfaces
  static const Color mediumGrey = Color(0xFF888888);
  
  // Semantic Colors
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
}

class AppTheme {
  // --- Light Theme (White Background, Golden Accents) ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.white,
    
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.black, // Black text on Golden button
      secondary: AppColors.primaryVariant,
      onSecondary: AppColors.black,
      surface: AppColors.white,
      onSurface: AppColors.black,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary, // Blue background
      foregroundColor: AppColors.white, // White text/icons
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.white, // White text
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.white), // White icons
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.grey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.mediumGrey),
      prefixIconColor: AppColors.mediumGrey,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.black),
      bodyMedium: TextStyle(color: AppColors.black),
      bodySmall: TextStyle(color: AppColors.mediumGrey),
    ),
    
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    
    iconTheme: const IconThemeData(color: AppColors.primary),
    dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE)),
  );

  // --- Dark Theme (Black Background, Golden Accents) ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.black,
    
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.black,
      secondary: AppColors.primaryVariant,
      onSecondary: AppColors.black,
      surface: AppColors.darkGrey,
      onSurface: AppColors.white,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.primary, // Golden icons/text on Black AppBar
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.mediumGrey),
      prefixIconColor: AppColors.mediumGrey,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.white),
      bodyMedium: TextStyle(color: AppColors.white),
      bodySmall: TextStyle(color: AppColors.mediumGrey),
    ),
    
    cardTheme: CardThemeData(
      color: AppColors.darkGrey,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    
    iconTheme: const IconThemeData(color: AppColors.primary),
    dividerTheme: const DividerThemeData(color: Color(0xFF333333)),
  );
}
