import 'package:flutter/material.dart';

class AppThemeData {
  final String name;
  final ThemeData themeData;
  final Color highlightColor;

  AppThemeData({
    required this.name,
    required this.themeData,
    required this.highlightColor,
  });
}

class AppThemes {
  static final Map<String, AppThemeData> themes = {
    'dracula': AppThemeData(
      name: 'Drácula',
      highlightColor: Colors.red,
      themeData: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFBD93F9),
          secondary: const Color(0xFFFF79C6),
          surface: const Color(0xFF282A36),
          onSurface: const Color(0xFFF8F8F2),
        ),
        scaffoldBackgroundColor: const Color(0xFF282A36),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF44475A),
          foregroundColor: Color(0xFFF8F8F2),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF44475A),
        ),
      ),
    ),
    'forest': AppThemeData(
      name: 'Bosque',
      highlightColor: Colors.lightGreen,
      themeData: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF8BC34A),
          surface: const Color(0xFF1B5E20),
          onSurface: const Color(0xFFE8F5E9),
        ),
        scaffoldBackgroundColor: const Color(0xFF1B5E20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Color(0xFFE8F5E9),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2E7D32),
        ),
      ),
    ),
    'midnight': AppThemeData(
      name: 'Medianoche',
      highlightColor: Colors.cyan,
      themeData: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFF42A5F5),
          surface: const Color(0xFF0A1929),
          onSurface: const Color(0xFFE3F2FD),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1929),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Color(0xFFE3F2FD),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1565C0),
        ),
      ),
    ),
    'monokai': AppThemeData(
      name: 'Monokai',
      highlightColor: Colors.yellow,
      themeData: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFF92672),
          secondary: const Color(0xFFA6E22E),
          surface: const Color(0xFF272822),
          onSurface: const Color(0xFFF8F8F2),
        ),
        scaffoldBackgroundColor: const Color(0xFF272822),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3E3D32),
          foregroundColor: Color(0xFFF8F8F2),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF3E3D32),
        ),
      ),
    ),
    'abyss': AppThemeData(
      name: 'Abismo',
      highlightColor: Colors.deepOrange,
      themeData: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFD32F2F),
          secondary: const Color(0xFFFF6F00),
          surface: const Color(0xFF000000),
          onSurface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF212121),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF212121),
        ),
      ),
    ),
  };

  static List<String> get themeNames => themes.keys.toList();
  
  static AppThemeData getTheme(String name) {
    return themes[name] ?? themes['dracula']!;
  }
}
