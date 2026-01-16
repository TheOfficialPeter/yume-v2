import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';
  static const String _easterEggModeKey = 'easter_egg_mode';
  static const String _autoSkipKey = 'auto_skip_intro_outro';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.deepOrange;
  bool _easterEggMode = false;
  bool _autoSkipEnabled = true; // Default to enabled

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get easterEggMode => _easterEggMode;
  bool get autoSkipEnabled => _autoSkipEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme mode
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // Load seed color
    final colorValue = prefs.getInt(_seedColorKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }

    // Load easter egg mode
    _easterEggMode = prefs.getBool(_easterEggModeKey) ?? false;

    // Load auto-skip preference
    _autoSkipEnabled = prefs.getBool(_autoSkipKey) ?? true;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    // Store color as ARGB integer
    final colorInt = (color.alpha << 24) |
        (color.red << 16) |
        (color.green << 8) |
        color.blue;
    await prefs.setInt(_seedColorKey, colorInt);
  }

  Future<void> setEasterEggMode(bool enabled) async {
    _easterEggMode = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_easterEggModeKey, enabled);
  }

  Future<void> setAutoSkipEnabled(bool enabled) async {
    _autoSkipEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSkipKey, enabled);
  }

  ThemeData getLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      fontFamily: 'GeistMono',
      useMaterial3: true,
    );
  }

  ThemeData getDarkTheme() {
    // Check if this is the AMOLED black theme
    final isAmoledBlack = _seedColor == const Color(0xFF101010);

    ColorScheme colorScheme;
    if (isAmoledBlack) {
      // Create true AMOLED black theme
      // Background: #101010, Accents/UI: #1E1E1E
      colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E1E1E),
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF101010),
        onSurface: Colors.white,
        surfaceContainerLowest: const Color(0xFF101010),
        surfaceContainerLow: const Color(0xFF1E1E1E),
        surfaceContainer: const Color(0xFF1E1E1E),
        surfaceContainerHigh: const Color(0xFF252525),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        primary: Colors.grey.shade400,
        onPrimary: Colors.black,
        primaryContainer: const Color(0xFF252525),
        onPrimaryContainer: Colors.grey.shade300,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      );
    }

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'GeistMono',
      useMaterial3: true,
      scaffoldBackgroundColor: isAmoledBlack ? const Color(0xFF101010) : null,
      appBarTheme: isAmoledBlack
          ? const AppBarTheme(
              surfaceTintColor: Colors.transparent,
            )
          : null,
      navigationBarTheme: isAmoledBlack
          ? NavigationBarThemeData(
              backgroundColor: const Color(0xFF1E1E1E),
              indicatorColor: const Color(0xFF252525),
              surfaceTintColor: Colors.transparent,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Colors.white);
                }
                return IconThemeData(color: Colors.grey.shade500);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(color: Colors.white, fontSize: 12);
                }
                return TextStyle(color: Colors.grey.shade500, fontSize: 12);
              }),
            )
          : null,
    );
  }
}
