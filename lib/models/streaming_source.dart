class StreamingSource {
  final String url;
  final bool isM3U8;
  final String? quality;

  StreamingSource({required this.url, required this.isM3U8, this.quality});

  factory StreamingSource.fromJson(Map<String, dynamic> json) {
    return StreamingSource(
      url: json['url'] as String,
      isM3U8: json['isM3U8'] as bool? ?? true,
      quality: json['quality'] as String?,
    );
  }
}

class Subtitle {
  final String lang;
  final String url;

  Subtitle({required this.lang, required this.url});

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(lang: json['lang'] as String, url: json['url'] as String);
  }
}

class StreamingData {
  final Map<String, String> headers;
  final List<StreamingSource> sources;
  final List<Subtitle> subtitles;
  final int? anilistID;
  final int? malID;

  StreamingData({
    required this.headers,
    required this.sources,
    required this.subtitles,
    this.anilistID,
    this.malID,
  });

  factory StreamingData.fromJson(Map<String, dynamic> json) {
    List<StreamingSource> parseSources(dynamic sourcesData) {
      if (sourcesData == null) return [];
      final List sourceList = sourcesData as List;
      return sourceList.map((json) => StreamingSource.fromJson(json)).toList();
    }

    List<Subtitle> parseSubtitles(dynamic subtitlesData) {
      if (subtitlesData == null) return [];
      final List subtitleList = subtitlesData as List;
      return subtitleList
          .map((json) => Subtitle.fromJson(json))
          .where((subtitle) => subtitle.lang.toLowerCase() != 'thumbnails')
          .toList();
    }

    Map<String, String> parseHeaders(dynamic headersData) {
      if (headersData == null) return {};
      final Map<String, dynamic> headersMap =
          headersData as Map<String, dynamic>;
      return headersMap.map((key, value) => MapEntry(key, value.toString()));
    }

    // Try 'tracks' first (new API format), fall back to 'subtitles' (old format)
    final subtitlesData = json['tracks'] ?? json['subtitles'];

    return StreamingData(
      headers: parseHeaders(json['headers']),
      sources: parseSources(json['sources']),
      subtitles: parseSubtitles(subtitlesData),
      anilistID: json['anilistID'] as int?,
      malID: json['malID'] as int?,
    );
  }
}
