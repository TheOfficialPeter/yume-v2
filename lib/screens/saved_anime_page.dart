import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime_info.dart';
import '../services/hianime_service.dart';
import '../services/saved_anime_service.dart';
import 'anime_detail_page.dart';

class SavedAnimePage extends StatefulWidget {
  final SavedAnimeService savedAnimeService;

  const SavedAnimePage({super.key, required this.savedAnimeService});

  @override
  State<SavedAnimePage> createState() => _SavedAnimePageState();
}

class _SavedAnimePageState extends State<SavedAnimePage> {
  final _hiAnimeService = HiAnimeService();
  Map<String, AnimeInfo> _animeInfoMap = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedAnime();
  }

  Future<void> _loadSavedAnime() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final savedIds = widget.savedAnimeService.savedAnimeIds;
      final Map<String, AnimeInfo> animeMap = {};

      // Fetch anime info for each saved ID
      for (final id in savedIds) {
        try {
          final info = await _hiAnimeService.getAnimeInfo(id);
          animeMap[id] = info;
        } catch (e) {
          // Skip anime that fail to load
        }
      }

      if (mounted) {
        setState(() {
          _animeInfoMap = animeMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getCorsProxiedUrl(String url) {
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Anime'),
        actions: [
          if (_animeInfoMap.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: _showClearAllDialog,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedAnime,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSavedAnime,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_animeInfoMap.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No saved anime yet',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the bookmark button on anime details to save',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: widget.savedAnimeService,
      builder: (context, child) {
        // Filter to only show anime that are still saved
        final currentSavedIds = widget.savedAnimeService.savedAnimeIds;
        final displayAnime = _animeInfoMap.entries
            .where((entry) => currentSavedIds.contains(entry.key))
            .toList();

        if (displayAnime.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No saved anime yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: displayAnime.length,
          itemBuilder: (context, index) {
            final entry = displayAnime[index];
            final animeId = entry.key;
            final anime = entry.value;

            return _GridAnimeCard(
              title: anime.name,
              imageUrl: anime.poster,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimeDetailPage(animeId: animeId),
                  ),
                );
              },
              onLongPress: () => _showRemoveDialog(animeId, anime.name),
              getCorsProxiedUrl: _getCorsProxiedUrl,
            );
          },
        );
      },
    );
  }

  void _showRemoveDialog(String animeId, String animeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from saved?'),
        content: Text('Remove "$animeName" from your saved anime?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.savedAnimeService.removeAnime(animeId);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Removed from saved')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all saved anime?'),
        content: const Text(
          'This will remove all anime from your saved list. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.savedAnimeService.clearAll();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All saved anime cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _GridAnimeCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String Function(String) getCorsProxiedUrl;

  const _GridAnimeCard({
    required this.title,
    this.imageUrl,
    this.onTap,
    this.onLongPress,
    required this.getCorsProxiedUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: getCorsProxiedUrl(imageUrl!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                      placeholder: (context, url) => Container(
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(Icons.image_outlined, size: 48),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
