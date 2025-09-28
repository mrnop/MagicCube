import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _useBundleFontKey = 'use_bundle_font';
  static const String _useSystemFontKey = 'use_system_font';

  bool _isDarkMode = false;
  bool _useBundleFont = true;
  bool _useSystemFont = false;

  bool get isDarkMode => _isDarkMode;
  bool get useBundleFont => _useBundleFont;
  bool get useSystemFont => _useSystemFont;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _useBundleFont = prefs.getBool(_useBundleFontKey) ?? true;
    _useSystemFont = prefs.getBool(_useSystemFontKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = !_isDarkMode;
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setUseBundleFont(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _useBundleFont = value;
    await prefs.setBool(_useBundleFontKey, value);
    notifyListeners();
  }

  Future<void> setUseSystemFont(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _useSystemFont = value;
    await prefs.setBool(_useSystemFontKey, value);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      );

  ThemeData get darkTheme => ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
      );

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;
}
