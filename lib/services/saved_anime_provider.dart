import 'package:flutter/material.dart';
import 'saved_anime_service.dart';

class SavedAnimeProvider extends InheritedWidget {
  final SavedAnimeService savedAnimeService;

  const SavedAnimeProvider({
    super.key,
    required this.savedAnimeService,
    required super.child,
  });

  static SavedAnimeService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SavedAnimeProvider>()
        ?.savedAnimeService;
  }

  @override
  bool updateShouldNotify(SavedAnimeProvider oldWidget) {
    return savedAnimeService != oldWidget.savedAnimeService;
  }
}
