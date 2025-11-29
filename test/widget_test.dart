// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yume/main.dart';
import 'package:yume/services/theme_service.dart';
import 'package:yume/services/saved_anime_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create service instances for testing
    final themeService = ThemeService();
    final savedAnimeService = SavedAnimeService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      themeService: themeService,
      savedAnimeService: savedAnimeService,
    ));

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
