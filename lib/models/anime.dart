class Anime {
  final String id;
  final String title;
  final String? imageUrl;
  final String? rating;
  final int? subEpisodes;
  final int? dubEpisodes;
  final String? type;
  final String? duration;

  Anime({
    required this.id,
    required this.title,
    this.imageUrl,
    this.rating,
    this.subEpisodes,
    this.dubEpisodes,
    this.type,
    this.duration,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String,
      title: json['name'] as String,
      imageUrl: json['poster'] as String?,
      rating: json['rating'] as String?,
      subEpisodes: json['episodes']?['sub'] as int?,
      dubEpisodes: json['episodes']?['dub'] as int?,
      type: json['type'] as String?,
      duration: json['duration'] as String?,
    );
  }
}
