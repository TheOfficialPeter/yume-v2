import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime_info.dart';
import '../models/episode.dart';
import '../models/recommendation.dart';
import '../models/watch_progress_entry.dart';
import '../services/hianime_service.dart';
import '../services/anilist_service.dart';
import '../services/jikan_service.dart';
import '../services/kitsu_service.dart';
import '../services/saved_anime_provider.dart';
import '../services/watch_progress_provider.dart';
import '../widgets/anime_card.dart';
import '../widgets/skeleton.dart';
import '../utils/episode_player_launcher.dart';
import 'search_page.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;

  const AnimeDetailPage({
    super.key,
    required this.animeId,
  });

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  final _hiAnimeService = HiAnimeService();
  final _aniListService = AniListService();
  final _jikanService = JikanService();
  final _kitsuService = KitsuService();
  final _scrollController = ScrollController();
  AnimeInfo? _animeInfo;
  List<Episode> _episodes = [];
  List<Episode> _displayedEpisodes = [];
  bool _isLoadingInfo = true;
  bool _isLoadingEpisodes = true;
  String? _errorInfo;
  String? _errorEpisodes;
  String? _highQualityCoverUrl;
  String? _bannerImageUrl;
  bool _isDescriptionExpanded = false;
  int? _malId;
  List<Recommendation> _recommendations = [];
  bool _isLoadingRecommendations = false;
  bool _isRecommendationsExpanded = false;

  static const int _episodesPerPage = 15;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadAnimeInfo();
    _loadEpisodes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _totalPages => (_episodes.length / _episodesPerPage).ceil();

  void _updateDisplayedEpisodes() {
    final startIndex = (_currentPage - 1) * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, _episodes.length);
    setState(() {
      _displayedEpisodes = _episodes.sublist(startIndex, endIndex);
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
    });
    _updateDisplayedEpisodes();

    // Fetch thumbnails for the new page
    if (_animeInfo != null && _kitsuAnimeId != null) {
      _fetchEpisodeThumbnails(
        malId: _malId,
        animeTitle: _animeInfo!.name,
      );
    }

    // Scroll to top of episode list
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onEpisodeTap(Episode episode) async {
    final animeTitle = _animeInfo?.name ?? 'Episode ${episode.number}';
    final posterUrl = _highQualityCoverUrl ?? _animeInfo?.poster;
    final watchProgressService = WatchProgressProvider.of(context);
    final entry = watchProgressService?.entryForAnime(widget.animeId);
    final bool hasResumeForEpisode =
        entry != null && entry.targetEpisodeNumber == episode.number;
    final initialPosition = hasResumeForEpisode ? entry!.positionSeconds : null;

    await EpisodePlayerLauncher.launch(
      context: context,
      episode: episode,
      animeId: widget.animeId,
      animeTitle: animeTitle,
      posterUrl: posterUrl,
      initialPositionSeconds: initialPosition,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAnimeInfo() async {
    setState(() {
      _isLoadingInfo = true;
      _errorInfo = null;
    });

    try {
      final info = await _hiAnimeService.getAnimeInfo(widget.animeId);
      setState(() {
        _animeInfo = info;
        _isLoadingInfo = false;
      });

      // Fetch high quality images from AniList in background
      _fetchHighQualityImages(info.name);
    } catch (e) {
      setState(() {
        _errorInfo = e.toString();
        _isLoadingInfo = false;
      });
    }
  }

  Future<void> _fetchHighQualityImages(String animeTitle) async {
    try {
      final images = await _aniListService.getAnimeImages(animeTitle);
      if (mounted && (images['cover'] != null || images['banner'] != null)) {
        setState(() {
          _highQualityCoverUrl = images['cover'];
          _bannerImageUrl = images['banner'];
        });
      }
    } catch (e) {
      // Silently fail - we'll use the original poster
    }
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoadingEpisodes = true;
      _errorEpisodes = null;
    });

    try {
      final episodes = await _hiAnimeService.getAnimeEpisodes(widget.animeId);
      setState(() {
        _episodes = episodes;
        _currentPage = 1;
        _isLoadingEpisodes = false;
      });
      _updateDisplayedEpisodes();
      final watchProgressService = WatchProgressProvider.of(context);
      watchProgressService?.cacheEpisodes(widget.animeId, episodes);

      // Fetch MAL ID and recommendations in the background
      if (episodes.isNotEmpty) {
        _fetchMalIdAndRecommendations(episodes.first.episodeId);
      }

      // Note: Episode thumbnails will be fetched after MAL ID is retrieved
    } catch (e) {
      setState(() {
        _errorEpisodes = e.toString();
        _isLoadingEpisodes = false;
      });
    }
  }

  String? _kitsuAnimeId;

  Future<void> _fetchEpisodeThumbnails({int? malId, String? animeTitle}) async {
    try {
      // Search for anime on Kitsu (cache the ID for future page changes)
      if (_kitsuAnimeId == null) {
        // Prefer MAL ID for more accurate matching
        if (malId != null) {
          _kitsuAnimeId = await _kitsuService.searchAnimeIdByMalId(malId);
        }

        // Fallback to title search if MAL ID fails or is not available
        if (_kitsuAnimeId == null && animeTitle != null) {
          _kitsuAnimeId = await _kitsuService.searchAnimeIdByTitle(animeTitle);
        }

        if (_kitsuAnimeId == null) return;
      }

      // Get episode numbers for currently displayed episodes
      final episodeNumbers = _displayedEpisodes.map((e) => e.number).toList();

      // Get episode thumbnails only for displayed episodes
      final thumbnailMap = await _kitsuService.getEpisodeThumbnails(
        _kitsuAnimeId!,
        episodeNumbers: episodeNumbers,
      );

      if (thumbnailMap.isEmpty || !mounted) return;

      // Update only the displayed episodes with thumbnails
      setState(() {
        _displayedEpisodes = _displayedEpisodes.map((episode) {
          final thumbnailUrl = thumbnailMap[episode.number];
          if (thumbnailUrl != null) {
            return episode.copyWith(thumbnailUrl: thumbnailUrl);
          }
          return episode;
        }).toList();

        // Also update the main episodes list
        _episodes = _episodes.map((episode) {
          final thumbnailUrl = thumbnailMap[episode.number];
          if (thumbnailUrl != null) {
            return episode.copyWith(thumbnailUrl: thumbnailUrl);
          }
          return episode;
        }).toList();
      });
    } catch (e) {
      // Silently fail - thumbnails are not critical
    }
  }

  Future<void> _fetchMalIdAndRecommendations(String episodeId) async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      // Fetch streaming sources to get MAL ID
      final streamingData = await _hiAnimeService.getStreamingSources(
        episodeId,
        server: 'hd-1',
        category: 'sub',
      );

      if (streamingData.malID != null) {
        setState(() {
          _malId = streamingData.malID;
        });

        // Fetch episode thumbnails using MAL ID
        if (_animeInfo != null) {
          _fetchEpisodeThumbnails(
            malId: streamingData.malID,
            animeTitle: _animeInfo!.name,
          );
        }

        // Fetch recommendations using MAL ID
        final recommendations = await _jikanService.getAnimeRecommendations(
          streamingData.malID!,
        );

        if (mounted) {
          setState(() {
            _recommendations = recommendations;
            _isLoadingRecommendations = false;
          });
        }
      } else {
        setState(() {
          _isLoadingRecommendations = false;
        });

        // Fallback to title-based search if no MAL ID
        if (_animeInfo != null) {
          _fetchEpisodeThumbnails(animeTitle: _animeInfo!.name);
        }
      }
    } catch (e) {
      // Silently fail - recommendations are not critical
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
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

  Widget _buildHeaderImage() {
    // Use high quality images if available, otherwise fall back to original poster
    final imageUrl =
        _bannerImageUrl ?? _highQualityCoverUrl ?? _animeInfo?.poster;

    if (imageUrl == null) {
      return Container(
        key: const ValueKey('no-image'),
        color: Colors.grey.withValues(alpha: 0.3),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Stack(
        key: ValueKey(imageUrl), // Unique key triggers animation on URL change
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _getCorsProxiedUrl(imageUrl),
            fit: BoxFit.cover,
            httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
            placeholder: (context, url) => const Skeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
            errorWidget: (context, url, error) {
              // If high quality image fails, try original poster
              if (imageUrl != _animeInfo?.poster && _animeInfo?.poster != null) {
                return CachedNetworkImage(
                  imageUrl: _getCorsProxiedUrl(_animeInfo!.poster!),
                  fit: BoxFit.cover,
                  httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                );
              }
              return Container(
                color: Colors.grey.withValues(alpha: 0.3),
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '',
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildHeaderImage()),
          ),
          SliverToBoxAdapter(child: _buildAnimeInfo()),
          _buildEpisodeList(),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final savedAnimeService = SavedAnimeProvider.of(context);
          if (savedAnimeService == null) return const SizedBox.shrink();

          return ListenableBuilder(
            listenable: savedAnimeService,
            builder: (context, child) {
              final isSaved = savedAnimeService.isAnimeSaved(widget.animeId);
              return FloatingActionButton(
                onPressed: () async {
                  final wasJustSaved = !isSaved;
                  await savedAnimeService.toggleAnime(widget.animeId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          wasJustSaved
                              ? 'Added to saved'
                              : 'Removed from saved',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnimeInfo() {
    if (_isLoadingInfo) {
      return const AnimeInfoSkeleton();
    }

    if (_errorInfo != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorInfo'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnimeInfo,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_animeInfo == null) return const SizedBox.shrink();

    final info = _animeInfo!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (info.rating != null) ...[
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  info.rating!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (info.type != null) ...[
                Chip(
                  label: Text(info.type!),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              if (info.status != null)
                Chip(
                  label: Text(info.status!),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (info.subEpisodes != null || info.dubEpisodes != null) ...[
            Row(
              children: [
                if (info.subEpisodes != null) ...[
                  const Icon(Icons.subtitles, size: 16),
                  const SizedBox(width: 4),
                  Text('${info.subEpisodes} episodes'),
                  const SizedBox(width: 16),
                ],
                if (info.dubEpisodes != null) ...[
                  const Icon(Icons.mic, size: 16),
                  const SizedBox(width: 4),
                  Text('${info.dubEpisodes} dubbed'),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (info.genres.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: info.genres.map((genre) {
                return Chip(
                  label: Text(genre),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (info.description != null) ...[
            const Text(
              'Synopsis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.description!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = true;
                      });
                    },
                    child: Text(
                      'Show more',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.description!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = false;
                      });
                    },
                    child: Text(
                      'Show less',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              crossFadeState: _isDescriptionExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
          const SizedBox(height: 24),
          _buildRecommendationsSection(),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    // Hide section if no MAL ID or if loading failed with no results
    if (_malId == null && !_isLoadingRecommendations) {
      return const SizedBox.shrink();
    }

    // Hide if finished loading but no recommendations
    if (!_isLoadingRecommendations && _recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoadingRecommendations
              ? null
              : () {
                  setState(() {
                    _isRecommendationsExpanded = !_isRecommendationsExpanded;
                  });
                },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isLoadingRecommendations)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _isRecommendationsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _isLoadingRecommendations
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: RecommendationsSkeleton(),
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = _recommendations[index];
                      return AnimeCard(
                        title: recommendation.title,
                        imageUrl: recommendation.imageUrl,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchPage(
                                initialQuery: recommendation.title,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
          crossFadeState: _isRecommendationsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_isLoadingEpisodes) {
      return const EpisodeListSkeleton();
    }

    if (_errorEpisodes != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error loading episodes: $_errorEpisodes'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadEpisodes,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_episodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
            child: const Text('No episodes available'),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Episodes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (_totalPages > 1)
                    Text(
                      'Page $_currentPage of $_totalPages',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                ],
              ),
            );
          }

          // Episode items
          final episodeIndex = index - 1;
          if (episodeIndex < _displayedEpisodes.length) {
            final episode = _displayedEpisodes[episodeIndex];
            final watchProgressService = WatchProgressProvider.of(context);

            Widget buildContent(
              EpisodeWatchStatus status,
              double progress,
            ) {
              return episode.thumbnailUrl != null
                  ? _buildEpisodeWithThumbnail(episode, status, progress)
                  : _buildEpisodeWithoutThumbnail(episode, status, progress);
            }

            Widget child;
            if (watchProgressService == null) {
              child = buildContent(EpisodeWatchStatus.notStarted, 0);
            } else {
              child = AnimatedBuilder(
                animation: watchProgressService,
                builder: (context, _) {
                  final status = watchProgressService.statusForEpisode(
                    widget.animeId,
                    episode.number,
                  );
                  final progress = watchProgressService.progressForEpisode(
                    widget.animeId,
                    episode.number,
                  );
                  return buildContent(status, progress);
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Card(
                child: InkWell(
                  onTap: () => _onEpisodeTap(episode),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  child: child,
                ),
              ),
            );
          }

          // Pagination controls at the bottom
          if (episodeIndex == _displayedEpisodes.length) {
            return _buildPaginationControls(bottomPadding);
          }

          return const SizedBox.shrink();
        },
        childCount:
            _displayedEpisodes.length + 2, // +1 for header, +1 for pagination
      ),
    );
  }

  Widget _buildEpisodeWithThumbnail(
    Episode episode,
    EpisodeWatchStatus status,
    double progress,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _getCorsProxiedUrl(episode.thumbnailUrl!),
              width: 120,
              height: 67.5, // 16:9 aspect ratio
              fit: BoxFit.cover,
              httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
              placeholder: (context, url) => Container(
                width: 120,
                height: 67.5,
                color: Colors.grey.withValues(alpha: 0.3),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 67.5,
                color: Colors.grey.withValues(alpha: 0.3),
                child: Center(
                  child: CircleAvatar(
                    child: Text(
                      '${episode.number}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Episode info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Episode ${episode.number}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.title ?? 'Episode ${episode.number}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status == EpisodeWatchStatus.inProgress && progress > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildEpisodeTrailing(status, episode.isFiller),
        ],
      ),
    );
  }

  Widget _buildEpisodeWithoutThumbnail(
    Episode episode,
    EpisodeWatchStatus status,
    double progress,
  ) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          '${episode.number}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      title: Text(
        episode.title ?? 'Episode ${episode.number}',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: status == EpisodeWatchStatus.inProgress && progress > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                ),
              ),
            )
          : null,
      trailing: _buildEpisodeTrailing(status, episode.isFiller),
    );
  }

  Widget _buildEpisodeTrailing(EpisodeWatchStatus status, bool isFiller) {
    if (isFiller) {
      return const Chip(
        label: Text('Filler'),
        labelStyle: TextStyle(fontSize: 10),
        visualDensity: VisualDensity.compact,
      );
    }

    switch (status) {
      case EpisodeWatchStatus.finished:
        return const Icon(Icons.check_circle, color: Colors.green);
      case EpisodeWatchStatus.inProgress:
        return const Icon(Icons.play_circle_fill);
      case EpisodeWatchStatus.notStarted:
      default:
        return const Icon(Icons.play_arrow);
    }
  }

  Widget _buildPaginationControls(double bottomPadding) {
    if (_totalPages <= 1) {
      return SizedBox(height: bottomPadding + 16);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      child: Column(
        children: [
          // Compact navigation controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                icon: const Icon(Icons.first_page),
                tooltip: 'First page',
              ),
              IconButton(
                onPressed:
                    _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),
              // Page indicator and jump to page
              InkWell(
                onTap: _showPageJumpDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_currentPage / $_totalPages',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPageJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Page number (1-$_totalPages)',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page >= 1 && page <= _totalPages) {
              Navigator.of(context).pop();
              _goToPage(page);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.of(context).pop();
                _goToPage(page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a number between 1 and $_totalPages',
                    ),
                  ),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}
