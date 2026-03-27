import 'package:flutter/material.dart';

class AppTheme {
  // === Spacing Constants (4pt base grid) ===
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // === Dark Mode Semantic Colors ===
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceRaised = Color(0xFF1C2128);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkBorderSubtle = Color(0xFF21262D);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextTertiary = Color(0xFF6E7681);
  static const Color darkAccent = Color(0xFF238636);
  static const Color darkAccentHover = Color(0xFF2EA043);
  static const Color darkAccentMuted = Color(0x26238636); // 15% opacity

  // === Light Mode Semantic Colors ===
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F8FA);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightBorderSubtle = Color(0xFFEAECEF);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);
  static const Color lightTextTertiary = Color(0xFF8C959F);
  static const Color lightAccent = Color(0xFF1A7F37);
  static const Color lightAccentHover = Color(0xFF2DA44E);
  static const Color lightAccentMuted = Color(0x1A1A7F37); // 10% opacity

  // Legacy constants for backward compatibility (deprecated)
  static const Color accentGreen = darkAccent;
  static const Color primaryDark = darkBackground;
  static const Color secondaryDark = darkSurface;
  static const Color backgroundDark = darkBackground;
  static const Color surfaceDark = darkSurface;
  static const Color cardDark = darkSurfaceRaised;
  static const Color terminalBackground = Color(0xFF1E1E1E);
  static const Color terminalForeground = Color(0xFFD4D4D4);

  // === Updated Themes ===

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.light(
      primary: lightAccent,
      secondary: lightAccent,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceRaised,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: lightSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorderSubtle,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: lightTextSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
      bodySmall: TextStyle(color: lightTextTertiary),
      labelLarge: TextStyle(color: lightTextSecondary),
      labelMedium: TextStyle(color: lightTextTertiary),
      labelSmall: TextStyle(color: lightTextTertiary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: lightBackground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkAccent,
      secondary: darkAccent,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceRaised,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: darkTextPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: darkSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: darkTextSecondary),
      hintStyle: const TextStyle(color: darkTextTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorderSubtle,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: darkTextSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: darkTextPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: darkTextPrimary),
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
      bodySmall: TextStyle(color: darkTextTertiary),
      labelLarge: TextStyle(color: darkTextSecondary),
      labelMedium: TextStyle(color: darkTextTertiary),
      labelSmall: TextStyle(color: darkTextTertiary),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: darkTextPrimary,
      iconColor: darkTextSecondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurfaceRaised,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
