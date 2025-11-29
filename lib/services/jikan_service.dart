import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4';

  Future<List<Recommendation>> getAnimeRecommendations(int malId) async {
    final url = '$_baseUrl/anime/$malId/recommendations';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final recommendationsData = data['data'] as List?;

      if (recommendationsData == null || recommendationsData.isEmpty) {
        return [];
      }

      // Parse and return only first 5 recommendations
      return recommendationsData
          .take(5)
          .map((json) => Recommendation.fromJson(json as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      // Anime not found or no recommendations available
      return [];
    } else {
      throw Exception(
        'Failed to load recommendations: ${response.statusCode}',
      );
    }
  }
}
