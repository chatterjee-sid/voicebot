import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF2C3E50);
  static const Color accentColor = Color(0xFF3498DB);
  static const Color secondaryColor = Color(0xFF16A085);
  static const Color backgroundColor = Color(0xFF1E1E2E);
  static const Color cardColor = Color(0xFF2A2D3E);
  static const Color textColor = Color(0xFFECF0F1);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF39C12);

  // Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      onPrimary: Colors.white,
      surface: Colors.white,
      background: Colors.grey[100]!,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    ),
    textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Roboto',
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
  );

  // Dark theme (futuristic look)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accentColor,
      secondary: secondaryColor,
      surface: cardColor,
      background: backgroundColor,
      onBackground: textColor,
      onSurface: textColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 6,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        shadowColor: accentColor.withOpacity(0.5),
      ),
    ),
    textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Roboto',
          bodyColor: textColor,
          displayColor: textColor,
        ),
    iconTheme: const IconThemeData(color: accentColor),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3D3D5C),
      thickness: 1,
    ),
    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardColor,
      selectedItemColor: accentColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),
  );
}
