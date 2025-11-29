import 'dart:convert';

enum EpisodeWatchStatus { notStarted, inProgress, finished }

class WatchProgressEntry {
  final String animeId;
  final String animeTitle;
  final String? posterUrl;
  final String? targetEpisodeId;
  final int targetEpisodeNumber;
  final double positionSeconds;
  final double durationSeconds;
  final String? serverName;
  final String? category;
  final List<int> completedEpisodes;
  final DateTime updatedAt;

  const WatchProgressEntry({
    required this.animeId,
    required this.animeTitle,
    this.posterUrl,
    required this.targetEpisodeId,
    required this.targetEpisodeNumber,
    required this.positionSeconds,
    required this.durationSeconds,
    this.serverName,
    this.category,
    this.completedEpisodes = const [],
    required this.updatedAt,
  });

  factory WatchProgressEntry.fromJson(Map<String, dynamic> json) {
    return WatchProgressEntry(
      animeId: json['animeId'] as String,
      animeTitle: json['animeTitle'] as String,
      posterUrl: json['posterUrl'] as String?,
      targetEpisodeId: json['targetEpisodeId'] as String?,
      targetEpisodeNumber: json['targetEpisodeNumber'] as int,
      positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
      serverName: json['serverName'] as String?,
      category: json['category'] as String?,
      completedEpisodes: (json['completedEpisodes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animeId': animeId,
      'animeTitle': animeTitle,
      'posterUrl': posterUrl,
      'targetEpisodeId': targetEpisodeId,
      'targetEpisodeNumber': targetEpisodeNumber,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'serverName': serverName,
      'category': category,
      'completedEpisodes': completedEpisodes,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  double get progress {
    if (durationSeconds <= 0) return 0;
    final ratio = positionSeconds / durationSeconds;
    if (ratio.isNaN || ratio.isInfinite) return 0;
    return ratio.clamp(0, 1);
  }

  bool get hasResumePoint => targetEpisodeId != null;

  EpisodeWatchStatus statusForEpisode(int episodeNumber) {
    if (completedEpisodes.contains(episodeNumber)) {
      return EpisodeWatchStatus.finished;
    }
    if (episodeNumber == targetEpisodeNumber && progress > 0) {
      return EpisodeWatchStatus.inProgress;
    }
    return EpisodeWatchStatus.notStarted;
  }

  WatchProgressEntry copyWith({
    String? animeId,
    String? animeTitle,
    String? posterUrl,
    String? targetEpisodeId,
    int? targetEpisodeNumber,
    double? positionSeconds,
    double? durationSeconds,
    String? serverName,
    String? category,
    List<int>? completedEpisodes,
    DateTime? updatedAt,
  }) {
    return WatchProgressEntry(
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      posterUrl: posterUrl ?? this.posterUrl,
      targetEpisodeId: targetEpisodeId ?? this.targetEpisodeId,
      targetEpisodeNumber: targetEpisodeNumber ?? this.targetEpisodeNumber,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      serverName: serverName ?? this.serverName,
      category: category ?? this.category,
      completedEpisodes: completedEpisodes ?? this.completedEpisodes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String encodeList(List<WatchProgressEntry> entries) {
    final data = entries.map((entry) => entry.toJson()).toList();
    return jsonEncode(data);
  }

  static List<WatchProgressEntry> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((item) => WatchProgressEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
