import 'dart:convert';
import 'package:http/http.dart' as http;

class KitsuService {
  static const String _baseUrl = 'https://kitsu.io/api/edge';

  /// Search for anime by MAL ID to get the Kitsu anime ID
  /// This is more accurate than searching by title
  Future<String?> searchAnimeIdByMalId(int malId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/mappings?filter[externalSite]=myanimelist/anime&filter[externalId]=$malId',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final mappings = data['data'] as List<dynamic>?;

        if (mappings != null && mappings.isNotEmpty) {
          // Get the Kitsu anime ID from the mapping relationship
          final relationships = mappings[0]['relationships'] as Map<String, dynamic>?;
          final item = relationships?['item'] as Map<String, dynamic>?;
          final itemData = item?['data'] as Map<String, dynamic>?;

          if (itemData != null && itemData['type'] == 'anime') {
            return itemData['id'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Search for anime by title to get the Kitsu anime ID (fallback method)
  Future<String?> searchAnimeIdByTitle(String animeTitle) async {
    try {
      final encodedTitle = Uri.encodeComponent(animeTitle);
      final url = Uri.parse('$_baseUrl/anime?filter[text]=$encodedTitle&page[limit]=1');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final animes = data['data'] as List<dynamic>?;

        if (animes != null && animes.isNotEmpty) {
          return animes[0]['id'] as String;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get episodes for an anime with thumbnails for specific episode range
  /// Returns a map where keys are episode numbers and values are thumbnail URLs
  ///
  /// [episodeNumbers] - List of episode numbers to fetch thumbnails for
  Future<Map<int, String?>> getEpisodeThumbnails(
    String kitsuAnimeId, {
    required List<int> episodeNumbers,
  }) async {
    try {
      if (episodeNumbers.isEmpty) return {};

      final thumbnailMap = <int, String?>{};

      // Calculate which pages we need to fetch based on episode numbers
      // Kitsu episodes are 1-indexed and returned in order
      final minEpisode = episodeNumbers.reduce((a, b) => a < b ? a : b);
      final maxEpisode = episodeNumbers.reduce((a, b) => a > b ? a : b);

      // Calculate page range (20 episodes per page)
      const pageLimit = 20;
      final startOffset = ((minEpisode - 1) ~/ pageLimit) * pageLimit;
      final endOffset = ((maxEpisode - 1) ~/ pageLimit) * pageLimit;

      // Fetch only the necessary pages
      for (var offset = startOffset; offset <= endOffset; offset += pageLimit) {
        final url = Uri.parse(
          '$_baseUrl/anime/$kitsuAnimeId/episodes?page[limit]=$pageLimit&page[offset]=$offset',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final episodes = data['data'] as List<dynamic>?;

          if (episodes == null || episodes.isEmpty) break;

          for (final episode in episodes) {
            final attributes = episode['attributes'] as Map<String, dynamic>?;
            if (attributes != null) {
              final number = attributes['number'] as int?;

              // Only process episodes we actually need
              if (number != null && episodeNumbers.contains(number)) {
                final thumbnail = attributes['thumbnail'] as Map<String, dynamic>?;
                String? thumbnailUrl;
                if (thumbnail != null && thumbnail['original'] != null) {
                  thumbnailUrl = thumbnail['original'] as String;
                }
                thumbnailMap[number] = thumbnailUrl;
              }
            }
          }
        }
      }

      return thumbnailMap;
    } catch (e) {
      return {};
    }
  }

  /// Get all episodes with full data including thumbnails, titles, and descriptions
  Future<List<KitsuEpisode>> getEpisodes(String kitsuAnimeId) async {
    try {
      final episodes = <KitsuEpisode>[];
      var pageOffset = 0;
      const pageLimit = 20; // Kitsu's maximum page size
      var hasMorePages = true;

      // Kitsu API uses pagination, fetch all pages
      while (hasMorePages) {
        final url = Uri.parse(
          '$_baseUrl/anime/$kitsuAnimeId/episodes?page[limit]=$pageLimit&page[offset]=$pageOffset',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final episodeData = data['data'] as List<dynamic>?;

          if (episodeData == null || episodeData.isEmpty) {
            hasMorePages = false;
            break;
          }

          for (final episode in episodeData) {
            final kitsuEpisode = KitsuEpisode.fromJson(episode);
            episodes.add(kitsuEpisode);
          }

          // Check if there are more pages
          pageOffset += pageLimit;
          if (episodeData.length < pageLimit) {
            hasMorePages = false;
          }
        } else {
          hasMorePages = false;
        }
      }

      return episodes;
    } catch (e) {
      return [];
    }
  }
}

class KitsuEpisode {
  final int number;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final int? length; // Duration in minutes
  final String? airDate;

  KitsuEpisode({
    required this.number,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.length,
    this.airDate,
  });

  factory KitsuEpisode.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>?;

    String? thumbnailUrl;
    if (attributes?['thumbnail'] != null) {
      final thumbnail = attributes!['thumbnail'] as Map<String, dynamic>?;
      thumbnailUrl = thumbnail?['original'] as String?;
    }

    return KitsuEpisode(
      number: attributes?['number'] as int? ?? 0,
      title: attributes?['canonicalTitle'] as String?,
      description: attributes?['synopsis'] as String?,
      thumbnailUrl: thumbnailUrl,
      length: attributes?['length'] as int?,
      airDate: attributes?['airdate'] as String?,
    );
  }
}
