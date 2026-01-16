import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../services/hianime_service.dart';
import 'anime_detail_page.dart';

class CategoryAnimePage extends StatefulWidget {
  final String category;
  final String displayTitle;

  const CategoryAnimePage({
    super.key,
    required this.category,
    required this.displayTitle,
  });

  @override
  State<CategoryAnimePage> createState() => _CategoryAnimePageState();
}

class _CategoryAnimePageState extends State<CategoryAnimePage> {
  final _hiAnimeService = HiAnimeService();
  List<Anime> _animeList = [];
  bool _isLoading = false;
  final int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadAnime();
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _hiAnimeService.getAnimeByCategory(
        widget.category,
        page: _currentPage,
      );
      setState(() {
        _animeList = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _animeList = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '',
        ),
        title: Text(widget.displayTitle),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_animeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No anime found in ${widget.displayTitle}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAnime, child: const Text('Retry')),
          ],
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _animeList.length,
      itemBuilder: (context, index) {
        final anime = _animeList[index];
        return _GridAnimeCard(
          title: anime.title,
          imageUrl: anime.imageUrl,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailPage(animeId: anime.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _GridAnimeCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _GridAnimeCard({required this.title, this.imageUrl, this.onTap});

  String _getCorsProxiedUrl(String url) {
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: _getCorsProxiedUrl(imageUrl!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                      placeholder: (context, url) => Container(
                        color: Colors.grey.withOpacity(0.3),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.withOpacity(0.3),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.3),
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
