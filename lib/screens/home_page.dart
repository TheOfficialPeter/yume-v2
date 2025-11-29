import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../services/hianime_service.dart';
import '../services/theme_service.dart';
import '../services/saved_anime_service.dart';
import '../widgets/anime_section.dart';
import '../widgets/continue_watching_section.dart';
import '../widgets/easter_egg_background.dart';
import 'category_anime_page.dart';
import 'genre_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'saved_anime_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    required this.themeService,
    required this.savedAnimeService,
  });

  final String title;
  final ThemeService themeService;
  final SavedAnimeService savedAnimeService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  final _hiAnimeService = HiAnimeService();
  final _searchController = TextEditingController();
  late Future<Map<String, List<Anime>>> _homeData;

  @override
  void initState() {
    super.initState();
    _homeData = _hiAnimeService.getHomeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    final wrappedBody = widget.themeService.easterEggMode
        ? EasterEggBackground(
            color: widget.themeService.seedColor,
            child: body,
          )
        : body;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 8),
            Text(widget.title),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Badge(isLabelVisible: false, child: Icon(Icons.home)),
            icon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.home_outlined),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.view_cozy),
            ),
            icon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.view_cozy_outlined),
            ),
            label: 'Genres',
          ),
          NavigationDestination(
            selectedIcon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.bookmark),
            ),
            icon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.bookmark_border),
            ),
            label: 'Saved',
          ),
          NavigationDestination(
            selectedIcon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.settings),
            ),
            icon: Badge(
              isLabelVisible: false,
              child: Icon(Icons.settings_outlined),
            ),
            label: 'Settings',
          ),
        ],
      ),
      body: wrappedBody,
    );
  }

  Widget _buildBody() {
    switch (currentPageIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const GenrePage();
      case 2:
        return SavedAnimePage(savedAnimeService: widget.savedAnimeService);
      case 3:
        return SettingsPage(themeService: widget.themeService);
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return FutureBuilder<Map<String, List<Anime>>>(
      future: _homeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _homeData = _hiAnimeService.getHomeData();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search anime...',
                  leading: const Icon(Icons.search),
                  autoFocus: false,
                  onSubmitted: (query) {
                    if (query.trim().isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchPage(initialQuery: query),
                        ),
                      );
                      _searchController.clear();
                    }
                  },
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                ),
              ),
              const ContinueWatchingSection(),
              if (data['trending']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Trending',
                  animeList: data['trending']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'most-popular',
                          displayTitle: 'Trending',
                        ),
                      ),
                    );
                  },
                ),
              if (data['latestEpisodes']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Latest Episodes',
                  animeList: data['latestEpisodes']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'recently-updated',
                          displayTitle: 'Latest Episodes',
                        ),
                      ),
                    );
                  },
                ),
              if (data['topUpcoming']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Top Upcoming',
                  animeList: data['topUpcoming']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'top-upcoming',
                          displayTitle: 'Top Upcoming',
                        ),
                      ),
                    );
                  },
                ),
              if (data['topAiring']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Top Airing',
                  animeList: data['topAiring']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'top-airing',
                          displayTitle: 'Top Airing',
                        ),
                      ),
                    );
                  },
                ),
              if (data['mostPopular']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Most Popular',
                  animeList: data['mostPopular']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'most-popular',
                          displayTitle: 'Most Popular',
                        ),
                      ),
                    );
                  },
                ),
              if (data['mostFavorite']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Most Favorite',
                  animeList: data['mostFavorite']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'most-favorite',
                          displayTitle: 'Most Favorite',
                        ),
                      ),
                    );
                  },
                ),
              if (data['completed']?.isNotEmpty ?? false)
                AnimeSection(
                  title: 'Recently Completed',
                  animeList: data['completed']!,
                  
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryAnimePage(
                          category: 'completed',
                          displayTitle: 'Recently Completed',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
