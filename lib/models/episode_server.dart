class EpisodeServer {
  final int serverId;
  final String serverName;

  EpisodeServer({required this.serverId, required this.serverName});

  factory EpisodeServer.fromJson(Map<String, dynamic> json) {
    return EpisodeServer(
      serverId: json['serverId'] as int,
      serverName: json['serverName'] as String,
    );
  }
}

class EpisodeServers {
  final String episodeId;
  final int episodeNo;
  final List<EpisodeServer> sub;
  final List<EpisodeServer> dub;
  final List<EpisodeServer> raw;

  EpisodeServers({
    required this.episodeId,
    required this.episodeNo,
    this.sub = const [],
    this.dub = const [],
    this.raw = const [],
  });

  factory EpisodeServers.fromJson(Map<String, dynamic> json) {
    List<EpisodeServer> parseServers(dynamic serversData) {
      if (serversData == null) return [];
      final List serverList = serversData as List;
      return serverList.map((json) => EpisodeServer.fromJson(json)).toList();
    }

    return EpisodeServers(
      episodeId: json['episodeId'] as String,
      episodeNo: json['episodeNo'] as int,
      sub: parseServers(json['sub']),
      dub: parseServers(json['dub']),
      raw: parseServers(json['raw']),
    );
  }

  bool get hasAnyServers => sub.isNotEmpty || dub.isNotEmpty || raw.isNotEmpty;
}
