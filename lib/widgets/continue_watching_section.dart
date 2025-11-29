import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../models/watch_progress_entry.dart';
import '../screens/anime_detail_page.dart';
import '../services/watch_progress_provider.dart';
import '../utils/episode_player_launcher.dart';

class ContinueWatchingSection extends StatelessWidget {
  const ContinueWatchingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final watchProgressService = WatchProgressProvider.of(context);
    if (watchProgressService == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: watchProgressService,
      builder: (context, _) {
        final entries = watchProgressService.resumableEntries;
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Continue Watching',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _ContinueWatchingCard(entry: entry);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

enum _ContinueWatchingAction { details, remove }

class _ContinueWatchingCard extends StatelessWidget {
  final WatchProgressEntry entry;

  const _ContinueWatchingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      onLongPress: () => _handleLongPress(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceVariant.withValues(
                alpha: 0.4,
              ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (entry.posterUrl != null)
                    CachedNetworkImage(
                      imageUrl: entry.posterUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.animeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Episode ${entry.targetEpisodeNumber}'
                            '${entry.category != null ? ' • ${entry.category!.toUpperCase()}' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        entry.progress > 0 ? 'Resume' : 'Start',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.progress > 0 ? entry.progress : 0,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLongPress(BuildContext context) async {
    final action = await showModalBottomSheet<_ContinueWatchingAction>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () => Navigator.of(sheetContext).pop(
                  _ContinueWatchingAction.details,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove from history'),
                onTap: () => Navigator.of(sheetContext).pop(
                  _ContinueWatchingAction.remove,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _ContinueWatchingAction.details:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AnimeDetailPage(animeId: entry.animeId),
          ),
        );
        break;
      case _ContinueWatchingAction.remove:
        final watchProgressService = WatchProgressProvider.of(context);
        watchProgressService?.removeEntry(entry.animeId);
        break;
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    if (entry.targetEpisodeId == null) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AnimeDetailPage(animeId: entry.animeId),
        ),
      );
      return;
    }

    final episode = Episode(
      number: entry.targetEpisodeNumber,
      title: null,
      episodeId: entry.targetEpisodeId!,
    );

    await EpisodePlayerLauncher.launch(
      context: context,
      episode: episode,
      animeId: entry.animeId,
      animeTitle: entry.animeTitle,
      posterUrl: entry.posterUrl,
      initialPositionSeconds:
          entry.progress > 0 ? entry.positionSeconds : null,
    );
  }
}
