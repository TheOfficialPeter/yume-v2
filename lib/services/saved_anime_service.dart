import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAnimeService extends ChangeNotifier {
  static const String _savedAnimeIdsKey = 'saved_anime_ids';

  List<String> _savedAnimeIds = [];

  List<String> get savedAnimeIds => List.unmodifiable(_savedAnimeIds);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved anime IDs
    final savedIds = prefs.getStringList(_savedAnimeIdsKey);
    if (savedIds != null) {
      _savedAnimeIds = savedIds;
    }

    notifyListeners();
  }

  bool isAnimeSaved(String animeId) {
    return _savedAnimeIds.contains(animeId);
  }

  Future<void> saveAnime(String animeId) async {
    if (!_savedAnimeIds.contains(animeId)) {
      _savedAnimeIds.add(animeId);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedAnimeIdsKey, _savedAnimeIds);
    }
  }

  Future<void> removeAnime(String animeId) async {
    if (_savedAnimeIds.contains(animeId)) {
      _savedAnimeIds.remove(animeId);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedAnimeIdsKey, _savedAnimeIds);
    }
  }

  Future<void> toggleAnime(String animeId) async {
    if (isAnimeSaved(animeId)) {
      await removeAnime(animeId);
    } else {
      await saveAnime(animeId);
    }
  }

  Future<void> clearAll() async {
    _savedAnimeIds.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedAnimeIdsKey);
  }
}
