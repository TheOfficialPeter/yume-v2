import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/skip_time.dart';

class AniSkipService {
  static const String _baseUrl = 'https://api.aniskip.com/v2';

  /// Fetch skip times for a specific anime episode
  ///
  /// [malId] - MyAnimeList ID of the anime
  /// [episodeNumber] - Episode number
  /// [episodeLength] - Optional episode length in seconds
  /// [types] - List of skip types to fetch (defaults to all types)
  Future<SkipTimesResponse?> getSkipTimes(
    int malId,
    int episodeNumber, {
    double? episodeLength,
    List<String>? types,
  }) async {
    try {
      // Default to all skip types if not specified
      final skipTypes = types ??
          ['op', 'ed', 'mixed-op', 'mixed-ed', 'recap'];

      // Build query string manually for array parameters
      final episodeLengthParam = episodeLength?.toStringAsFixed(3) ?? '0';
      final typesParams = skipTypes.map((type) => 'types[]=$type').join('&');
      final queryString = 'episodeLength=$episodeLengthParam&$typesParams';

      final uri = Uri.parse(
        '$_baseUrl/skip-times/$malId/$episodeNumber?$queryString',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SkipTimesResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        // No skip times found - return empty response
        return SkipTimesResponse(
          found: false,
          results: [],
          message: 'No skip times found',
          statusCode: 404,
        );
      } else {
        throw Exception('Failed to load skip times: ${response.statusCode}');
      }
    } catch (e) {
      // Silently fail and return null - skip times are not critical
      return null;
    }
  }

  /// Get only opening skip time
  Future<SkipTimeResult?> getOpeningSkipTime(
    int malId,
    int episodeNumber,
  ) async {
    final response = await getSkipTimes(
      malId,
      episodeNumber,
      types: ['op', 'mixed-op'],
    );

    if (response != null && response.found && response.results.isNotEmpty) {
      return response.results.firstWhere(
        (r) => r.isOpening,
        orElse: () => response.results.first,
      );
    }

    return null;
  }

  /// Get only ending skip time
  Future<SkipTimeResult?> getEndingSkipTime(
    int malId,
    int episodeNumber,
  ) async {
    final response = await getSkipTimes(
      malId,
      episodeNumber,
      types: ['ed', 'mixed-ed'],
    );

    if (response != null && response.found && response.results.isNotEmpty) {
      return response.results.firstWhere(
        (r) => r.isEnding,
        orElse: () => response.results.first,
      );
    }

    return null;
  }
}
