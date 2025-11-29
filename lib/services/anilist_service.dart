import 'dart:convert';
import 'package:http/http.dart' as http;

class AniListService {
  static const String _graphqlUrl = 'https://graphql.anilist.co';

  /// Search for anime on AniList and return high quality cover image
  Future<String?> getHighQualityCoverImage(String animeTitle) async {
    try {
      // GraphQL query to search for anime
      const query = '''
        query (\$search: String) {
          Media(search: \$search, type: ANIME) {
            id
            title {
              romaji
              english
              native
            }
            coverImage {
              extraLarge
              large
              medium
            }
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'variables': {'search': animeTitle},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final media = data['data']?['Media'];

        if (media != null) {
          // Try to get the highest quality image available
          final coverImage = media['coverImage'];
          return coverImage['extraLarge'] ??
              coverImage['large'] ??
              coverImage['medium'];
        }
      }
    } catch (e) {
      // Failed to fetch AniList cover image
    }
    return null;
  }

  /// Get anime details including banner image
  Future<Map<String, String?>> getAnimeImages(String animeTitle) async {
    try {
      const query = '''
        query (\$search: String) {
          Media(search: \$search, type: ANIME) {
            id
            title {
              romaji
              english
              native
            }
            coverImage {
              extraLarge
              large
            }
            bannerImage
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'variables': {'search': animeTitle},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final media = data['data']?['Media'];

        if (media != null) {
          final coverImage = media['coverImage'];
          return {
            'cover': coverImage['extraLarge'] ?? coverImage['large'],
            'banner': media['bannerImage'],
          };
        }
      }
    } catch (e) {
      // Failed to fetch AniList images
    }
    return {'cover': null, 'banner': null};
  }
}
