import 'package:flutter/material.dart';

/// A centralized theme definition for the app.
class AppTheme {
  // Primary and accent colors
  static const Color primaryColor = Colors.blue;
  static const Color accentColor = Colors.blueAccent;

  // Text styles
  static final TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );

  /// Light theme data
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.blue,
    ).copyWith(
      secondary: accentColor,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      titleTextStyle: textTheme.titleLarge!.copyWith(color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor),
      ),
    ),
  );
}
