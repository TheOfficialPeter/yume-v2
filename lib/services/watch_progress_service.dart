import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/episode.dart';
import '../models/watch_progress_entry.dart';

class WatchProgressService extends ChangeNotifier {
  static const _entriesKey = 'watch_progress_entries';
  static const _episodeCacheKey = 'watch_progress_episode_cache';

  final Map<String, WatchProgressEntry> _entries = {};
  final Map<String, Map<int, String>> _episodeIdCache = {};

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final rawEntries = _prefs?.getString(_entriesKey);
    if (rawEntries != null) {
      for (final entry in WatchProgressEntry.decodeList(rawEntries)) {
        _entries[entry.animeId] = entry;
      }
    }

    final rawEpisodeCache = _prefs?.getString(_episodeCacheKey);
    if (rawEpisodeCache != null) {
      final decoded = jsonDecode(rawEpisodeCache) as Map<String, dynamic>;
      decoded.forEach((animeId, value) {
        final Map<int, String> map = {};
        (value as Map<String, dynamic>).forEach((key, val) {
          map[int.parse(key)] = val as String;
        });
        _episodeIdCache[animeId] = map;
      });
    }
  }

  List<WatchProgressEntry> get entries {
    final list = _entries.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<WatchProgressEntry> get resumableEntries {
    return entries.where((entry) => entry.targetEpisodeId != null).toList();
  }

  void cacheEpisodes(String animeId, List<Episode> episodes) {
    if (episodes.isEmpty) return;
    final map = {for (final episode in episodes) episode.number: episode.episodeId};
    _episodeIdCache[animeId] = map;
    _saveEpisodeCache();

    final entry = _entries[animeId];
    if (entry != null && entry.targetEpisodeId == null) {
      final cachedId = map[entry.targetEpisodeNumber];
      if (cachedId != null) {
        _entries[animeId] = entry.copyWith(targetEpisodeId: cachedId);
        _saveEntries();
        notifyListeners();
      }
    }
  }

  void updateProgress({
    required String animeId,
    required String animeTitle,
    String? posterUrl,
    required String episodeId,
    required int episodeNumber,
    required double positionSeconds,
    required double durationSeconds,
    required String serverName,
    required String category,
  }) {
    final now = DateTime.now();
    final existing = _entries[animeId];
    final completedEpisodes =
        List<int>.from(existing?.completedEpisodes ?? const <int>[]);

    _entries[animeId] = WatchProgressEntry(
      animeId: animeId,
      animeTitle: animeTitle,
      posterUrl: posterUrl ?? existing?.posterUrl,
      targetEpisodeId: episodeId,
      targetEpisodeNumber: episodeNumber,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      serverName: serverName,
      category: category,
      completedEpisodes: completedEpisodes,
      updatedAt: now,
    );

    _saveEntries();
    notifyListeners();
  }

  void markEpisodeFinished({
    required String animeId,
    required String animeTitle,
    String? posterUrl,
    required String episodeId,
    required int episodeNumber,
    required String serverName,
    required String category,
  }) {
    final now = DateTime.now();
    final existing = _entries[animeId];
    final completedEpisodes = <int>{
      if (existing != null) ...existing.completedEpisodes,
      episodeNumber,
    }.toList()
      ..sort();

    final nextEpisodeNumber = episodeNumber + 1;
    final nextEpisodeId = _episodeIdCache[animeId]?[nextEpisodeNumber];

    _entries[animeId] = (existing ??
            WatchProgressEntry(
              animeId: animeId,
              animeTitle: animeTitle,
              posterUrl: posterUrl,
              targetEpisodeId: episodeId,
              targetEpisodeNumber: episodeNumber,
              positionSeconds: 0,
              durationSeconds: 0,
              serverName: serverName,
              category: category,
              completedEpisodes: completedEpisodes,
              updatedAt: now,
            ))
        .copyWith(
      animeId: animeId,
      animeTitle: animeTitle,
      posterUrl: posterUrl ?? existing?.posterUrl,
      targetEpisodeId: nextEpisodeId,
      targetEpisodeNumber: nextEpisodeNumber,
      positionSeconds: 0,
      durationSeconds: 0,
      serverName: serverName,
      category: category,
      completedEpisodes: completedEpisodes,
      updatedAt: now,
    );

    _saveEntries();
    notifyListeners();
  }

  EpisodeWatchStatus statusForEpisode(String animeId, int episodeNumber) {
    final entry = _entries[animeId];
    if (entry == null) return EpisodeWatchStatus.notStarted;
    return entry.statusForEpisode(episodeNumber);
  }

  double progressForEpisode(String animeId, int episodeNumber) {
    final entry = _entries[animeId];
    if (entry == null) return 0;
    if (entry.targetEpisodeNumber != episodeNumber) return 0;
    return entry.progress;
  }

  WatchProgressEntry? entryForAnime(String animeId) => _entries[animeId];

  void removeEntry(String animeId) {
    if (_entries.remove(animeId) != null) {
      _saveEntries();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    _entries.clear();
    _episodeIdCache.clear();
    _saveEntries();
    _saveEpisodeCache();
    notifyListeners();
  }

  String? episodeIdFor(String animeId, int episodeNumber) {
    return _episodeIdCache[animeId]?[episodeNumber];
  }

  void _saveEntries() {
    final encoded = WatchProgressEntry.encodeList(_entries.values.toList());
    _prefs?.setString(_entriesKey, encoded);
  }

  void _saveEpisodeCache() {
    final encoded = _episodeIdCache.map((animeId, map) {
      final mapped = map.map((key, value) => MapEntry(key.toString(), value));
      return MapEntry(animeId, mapped);
    });
    _prefs?.setString(_episodeCacheKey, jsonEncode(encoded));
  }
}
