class Episode {
  final int number;
  final String? title;
  final String episodeId;
  final bool isFiller;
  final String? thumbnailUrl;

  Episode({
    required this.number,
    this.title,
    required this.episodeId,
    this.isFiller = false,
    this.thumbnailUrl,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      number: json['number'] as int,
      title: json['title'] as String?,
      episodeId: json['episodeId'] as String,
      isFiller: json['isFiller'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  /// Create a copy of this episode with updated fields
  Episode copyWith({
    int? number,
    String? title,
    String? episodeId,
    bool? isFiller,
    String? thumbnailUrl,
  }) {
    return Episode(
      number: number ?? this.number,
      title: title ?? this.title,
      episodeId: episodeId ?? this.episodeId,
      isFiller: isFiller ?? this.isFiller,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
