import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/anime.dart';
import '../models/anime_info.dart';
import '../models/episode.dart';
import '../models/episode_server.dart';
import '../models/streaming_source.dart';

class HiAnimeService {
  final String _baseUrl = dotenv.env['HIANIME_API_URL'] ?? '';

  Future<Map<String, List<Anime>>> getHomeData() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v2/hianime/home'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final homeData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return {
        'trending': _parseAnimeList(homeData['trendingAnimes']),
        'latestEpisodes': _parseAnimeList(homeData['latestEpisodeAnimes']),
        'topUpcoming': _parseAnimeList(homeData['topUpcomingAnimes']),
        'topAiring': _parseAnimeList(homeData['topAiringAnimes']),
        'mostPopular': _parseAnimeList(homeData['mostPopularAnimes']),
        'mostFavorite': _parseAnimeList(homeData['mostFavoriteAnimes']),
        'completed': _parseAnimeList(homeData['latestCompletedAnimes']),
      };
    } else {
      throw Exception('Failed to load home data: ${response.statusCode}');
    }
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v2/hianime/search?q=$query&page=$page'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final searchData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return _parseAnimeList(searchData['animes']);
    } else {
      throw Exception('Failed to search anime: ${response.statusCode}');
    }
  }

  Future<List<Anime>> getAnimeByGenre(String genre, {int page = 1}) async {
    final genreParam = genre.toLowerCase().replaceAll(' ', '-');
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v2/hianime/genre/$genreParam?page=$page'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final genreData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return _parseAnimeList(genreData['animes']);
    } else {
      throw Exception('Failed to load genre anime: ${response.statusCode}');
    }
  }

  Future<List<Anime>> getAnimeByCategory(
    String category, {
    int page = 1,
  }) async {
    final categoryParam = category.toLowerCase().replaceAll(' ', '-');
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v2/hianime/category/$categoryParam?page=$page'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final categoryData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return _parseAnimeList(categoryData['animes']);
    } else {
      throw Exception('Failed to load category anime: ${response.statusCode}');
    }
  }

  Future<AnimeInfo> getAnimeInfo(String animeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v2/hianime/anime/$animeId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final animeData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return AnimeInfo.fromJson(animeData);
    } else {
      throw Exception('Failed to load anime info: ${response.statusCode}');
    }
  }

  Future<List<Episode>> getAnimeEpisodes(String animeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v2/hianime/anime/$animeId/episodes'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final episodeData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return _parseEpisodeList(episodeData['episodes']);
    } else {
      throw Exception('Failed to load episodes: ${response.statusCode}');
    }
  }

  List<Anime> _parseAnimeList(dynamic animeData) {
    if (animeData == null) return [];
    final List animeList = animeData as List;
    return animeList.map((json) => Anime.fromJson(json)).toList();
  }

  Future<EpisodeServers> getEpisodeServers(String episodeId) async {
    final encodedEpisodeId = Uri.encodeComponent(episodeId);
    final url =
        '$_baseUrl/api/v2/hianime/episode/servers?animeEpisodeId=$encodedEpisodeId';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://hianime.to/',
        'Origin': 'https://hianime.to',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final serverData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return EpisodeServers.fromJson(serverData);
    } else {
      throw Exception('Failed to load episode servers: ${response.statusCode}');
    }
  }

  Future<StreamingData> getStreamingSources(
    String episodeId, {
    String server = 'hd-1',
    String category = 'sub',
  }) async {
    final encodedEpisodeId = Uri.encodeComponent(episodeId);
    final url =
        '$_baseUrl/api/v2/hianime/episode/sources?animeEpisodeId=$encodedEpisodeId&server=$server&category=$category';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://hianime.to/',
        'Origin': 'https://hianime.to',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle both with and without 'success' field
      final sourceData = data['data'] != null
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      return StreamingData.fromJson(sourceData);
    } else {
      throw Exception(
        'Failed to load streaming sources: ${response.statusCode}',
      );
    }
  }

  List<Episode> _parseEpisodeList(dynamic episodeData) {
    if (episodeData == null) return [];
    final List episodeList = episodeData as List;
    return episodeList.map((json) => Episode.fromJson(json)).toList();
  }
}
