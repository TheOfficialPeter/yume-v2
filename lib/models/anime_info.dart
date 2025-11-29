class AnimeInfo {
  final String id;
  final String name;
  final String? description;
  final String? poster;
  final String? rating;
  final String? type;
  final String? status;
  final List<String> genres;
  final int? subEpisodes;
  final int? dubEpisodes;
  final String? duration;
  final String? aired;
  final String? japaneseTitle;

  AnimeInfo({
    required this.id,
    required this.name,
    this.description,
    this.poster,
    this.rating,
    this.type,
    this.status,
    this.genres = const [],
    this.subEpisodes,
    this.dubEpisodes,
    this.duration,
    this.aired,
    this.japaneseTitle,
  });

  factory AnimeInfo.fromJson(Map<String, dynamic> json) {
    // Handle the nested structure: data.anime.info and data.anime.moreInfo
    final anime = json['anime'] as Map<String, dynamic>? ?? json;
    final info = anime['info'] as Map<String, dynamic>? ?? anime;
    final moreInfo = anime['moreInfo'] as Map<String, dynamic>? ?? {};
    final stats = info['stats'] as Map<String, dynamic>? ?? {};

    // Parse genres
    List<String> genresList = [];
    if (moreInfo['genres'] != null) {
      genresList = (moreInfo['genres'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (info['genres'] != null) {
      genresList = (info['genres'] as List).map((e) => e.toString()).toList();
    }

    return AnimeInfo(
      id: info['id'] as String? ?? '',
      name: info['name'] as String? ?? 'Unknown',
      description: info['description'] as String?,
      poster: info['poster'] as String?,
      rating: stats['rating'] as String?,
      type: stats['type'] as String?,
      status: moreInfo['status'] as String?,
      genres: genresList,
      subEpisodes: stats['episodes']?['sub'] as int?,
      dubEpisodes: stats['episodes']?['dub'] as int?,
      duration: stats['duration'] as String? ?? moreInfo['duration'] as String?,
      aired: moreInfo['aired'] as String?,
      japaneseTitle: moreInfo['japanese'] as String?,
    );
  }
}
