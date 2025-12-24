import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          secondary: Color(0xFF1976D2),
          surface: Color(0xFFF5F5F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xCCFFFFFF),
          indicatorColor: Colors.blue.withValues(alpha: 0.15),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Color(0xFF64B5F6),
          surface: Color(0xFF0D0D0F),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0x14FFFFFF),
          indicatorColor: Colors.blue.withValues(alpha: 0.2),
        ),
      );
}

extension GlassTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get glassColor => isDark
      ? const Color(0x14FFFFFF)
      : const Color(0xB3FFFFFF);

  Color get glassBorderColor => isDark
      ? const Color(0x26FFFFFF)
      : const Color(0x14000000);

  Color get glassTextColor => isDark ? Colors.white : Colors.black;

  Color get secondaryTextColor => isDark
      ? const Color(0x99FFFFFF)
      : const Color(0x80000000);
}
