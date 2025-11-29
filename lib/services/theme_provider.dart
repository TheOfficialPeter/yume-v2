import 'package:flutter/material.dart';
import 'theme_service.dart';

class ThemeProvider extends InheritedWidget {
  final ThemeService themeService;

  const ThemeProvider({
    super.key,
    required this.themeService,
    required super.child,
  });

  static ThemeService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeProvider>()
        ?.themeService;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeService != oldWidget.themeService;
  }
}
