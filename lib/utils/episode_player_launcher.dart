import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../screens/video_player_page.dart';
import '../services/hianime_service.dart';
import '../widgets/server_selection_modal.dart';

class EpisodePlayerLauncher {
  EpisodePlayerLauncher._();

  static final HiAnimeService _hiAnimeService = HiAnimeService();

  static Future<void> launch({
    required BuildContext context,
    required Episode episode,
    required String animeId,
    required String animeTitle,
    String? posterUrl,
    double? initialPositionSeconds,
  }) async {
    // Show loading indicator while fetching servers
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final servers = await _hiAnimeService.getEpisodeServers(episode.episodeId);

      if (context.mounted) Navigator.of(context).pop();

      if (!servers.hasAnyServers) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No streaming servers available')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final selection = await ServerSelectionModal.show(context, servers);
      if (selection == null || !context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            animeId: animeId,
            animeTitle: animeTitle,
            posterUrl: posterUrl,
            episode: episode,
            serverName: selection.serverName,
            category: selection.category,
            initialPositionSeconds: initialPositionSeconds,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
