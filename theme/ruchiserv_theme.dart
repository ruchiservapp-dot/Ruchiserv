// lib/theme/ruchiserv_theme.dart
import 'package:flutter/material.dart';

class RuchiServTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF1877F2), // Facebook Blue
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF1877F2),
      secondary: Colors.blueAccent.shade100,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1877F2),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    scaffoldBackgroundColor: Colors.grey.shade50,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF1E1E2C), // Dark blue-grey tone
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF1E1E2C),
      secondary: Colors.blueGrey.shade300,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E2C),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}
