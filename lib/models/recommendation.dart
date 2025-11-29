class Recommendation {
  final int malId;
  final String title;
  final String? imageUrl;

  Recommendation({
    required this.malId,
    required this.title,
    this.imageUrl,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final entry = json['entry'] as Map<String, dynamic>;

    // Extract English title from titles array
    String title = entry['title'] as String; // Default/romanji title

    final titles = entry['titles'] as List<dynamic>?;
    if (titles != null) {
      // Try to find English title first
      final englishTitle = titles.firstWhere(
        (t) => t['type'] == 'English',
        orElse: () => null,
      );

      if (englishTitle != null && englishTitle['title'] != null) {
        title = englishTitle['title'] as String;
      } else {
        // Fallback to Default type if English not found
        final defaultTitle = titles.firstWhere(
          (t) => t['type'] == 'Default',
          orElse: () => null,
        );
        if (defaultTitle != null && defaultTitle['title'] != null) {
          title = defaultTitle['title'] as String;
        }
      }
    }

    return Recommendation(
      malId: entry['mal_id'] as int,
      title: title,
      imageUrl: entry['images']?['jpg']?['large_image_url'] as String? ??
          entry['images']?['jpg']?['image_url'] as String?,
    );
  }
}
