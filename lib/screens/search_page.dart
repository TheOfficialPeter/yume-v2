import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../services/hianime_service.dart';
import 'anime_detail_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _hiAnimeService = HiAnimeService();
  final _searchController = TextEditingController();
  List<Anime> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _hiAnimeService.searchAnime(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
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
        title: const Text('Results'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for anime',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
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
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final anime = _searchResults[index];
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
