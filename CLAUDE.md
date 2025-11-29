# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yume is a Flutter anime streaming application that integrates with multiple external APIs to provide anime browsing, search, and video playback functionality. The app uses Material Design 3 with a custom GeistMono font and supports extensive theming customization.

## Development Commands

### Running the App
```bash
flutter run                    # Run in debug mode
flutter run --release          # Run in release mode
```

### Building
```bash
flutter build apk --release    # Android APK
flutter build appbundle        # Android App Bundle (for Play Store)
flutter build ios --release    # iOS build
flutter build web --release    # Web build
```

### Code Quality
```bash
flutter analyze                # Run static analysis
flutter test                   # Run tests
flutter pub get                # Install/update dependencies
```

### Icons
```bash
flutter pub run flutter_launcher_icons  # Generate app icons
```

## Environment Setup

**Required:** Create a `.env` file in the root directory with:
```env
HIANIME_API_URL=your_api_endpoint_here
```

The app requires the [aniwatch-api](https://github.com/ghoshRitesh12/aniwatch-api) backend to be running. Follow the setup instructions at that repository to get the API endpoint.

## Architecture Overview

### State Management Pattern

The app uses a **hybrid state management approach** without external state management libraries:

1. **Global Observable Services** - `ChangeNotifier` for theme and saved anime state
   - `ThemeService`: Manages theme mode, seed color, preferences (via `ListenableBuilder`)
   - `SavedAnimeService`: Manages user's saved anime list (via custom `InheritedWidget`)

2. **Local Stateful Widgets** - Each screen manages its own data and loading states
   - Screens directly instantiate API services and manage API call results
   - Loading, error, and data states are managed locally within screen widgets

3. **Dependency Injection** - Manual DI through constructor parameters
   - Services are instantiated in `main.dart` and passed through widget tree
   - No global singletons or service locators

### Service Layer Architecture

The app coordinates **four external APIs** for complete anime information:

**Primary API:**
- **HiAnimeService** - Main anime data provider (search, info, episodes, streaming sources)

**Enrichment APIs** (called asynchronously to enhance data):
- **AniListService** - High-quality cover images and banners (GraphQL)
- **JikanService** - Anime recommendations via MyAnimeList
- **KitsuService** - Episode thumbnails, titles, and metadata

**Key Pattern:** Screens make parallel API calls where possible and handle failures gracefully:
```dart
// AnimeDetailPage example
void initState() {
  _loadAnimeInfo();      // Primary data
  _loadEpisodes();       // Primary data
  // Then asynchronously:
  _fetchHighQualityImages();      // Enhancement (can fail silently)
  _fetchMalIdAndRecommendations(); // Enhancement (can fail silently)
}
```

### Navigation Structure

Simple **MaterialPageRoute-based navigation** (no named routes):
```
HomePage (TabBar: Home, Genres, Saved, Settings)
  ├─> AnimeDetailPage (anime info + episodes)
  │     └─> ServerSelectionModal (bottom sheet)
  │           └─> VideoPlayerPage (fullscreen video)
  ├─> GenrePage → GenreAnimePage
  ├─> SearchPage (with optional initialQuery)
  └─> SettingsPage
```

## Key Architectural Decisions

### Multi-API Coordination Pattern

**AnimeDetailPage** demonstrates the core pattern used throughout the app:

1. Load critical data first (HiAnime info + episodes)
2. Extract identifiers (MAL ID, Kitsu ID) from initial responses
3. Make parallel enhancement API calls in background
4. Update UI incrementally as enrichment data arrives
5. Handle enrichment failures silently (non-critical)

Example from [screens/anime_detail_page.dart](screens/anime_detail_page.dart:143-249):
```dart
// Critical path (blocking)
final info = await _hiAnimeService.getAnimeInfo(widget.animeId);
final episodes = await _hiAnimeService.getAnimeEpisodes(widget.animeId);

// Enhancement path (background, non-blocking)
_fetchHighQualityImages(info.name);           // AniList
_fetchMalIdAndRecommendations(episode.id);     // Jikan + Kitsu
```

### Video Playback Flow

The video playback requires a multi-step server selection process:

1. User taps episode → Fetch available servers
2. Show `ServerSelectionModal` (sub/dub/raw categories)
3. User selects server → Fetch streaming sources
4. Navigate to `VideoPlayerPage` with sources
5. Set landscape orientation + fullscreen
6. Initialize Chewie video player with m3u8 sources + VTT subtitles

### Pagination Pattern

Episodes use custom pagination (15 per page) implemented in [screens/anime_detail_page.dart](screens/anime_detail_page.dart:48-86):
- Display 15 episodes at a time from `_displayedEpisodes`
- Custom navigation controls: First, Previous, Next, Last, Jump to Page
- Scroll to top when page changes

Genre and category pages also use pagination but fetch new pages from API on navigation.

### Theme System

Material 3 dynamic theming with user-selectable seed colors:
- 24 color options defined in [screens/settings_page.dart](screens/settings_page.dart)
- `ThemeService` generates light/dark themes from seed color
- Changes propagate via `ChangeNotifier` → `ListenableBuilder` in main.dart
- GeistMono monospace font applied globally

### Image Loading Strategy

**CORS Handling for Web:**
```dart
String _getCorsProxiedUrl(String url) {
  if (kIsWeb) {
    return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
  }
  return url;
}
```

**Caching:** Uses `cached_network_image` with skeleton loading states (not circular progress indicators).

## Important File Locations

### Critical Screens
- **AnimeDetailPage** - Most complex screen, demonstrates multi-API coordination
- **VideoPlayerPage** - Handles video playback, orientation changes, fullscreen
- **HomePage** - Main hub with tab navigation and multiple anime sections

### Core Services
- **HiAnimeService** - Primary API with 7+ methods for all anime operations
- **SavedAnimeService** + **SavedAnimeProvider** - Shows InheritedWidget pattern
- **ThemeService** - Shows ChangeNotifier + SharedPreferences pattern

### Reusable Widgets
- **ServerSelectionModal** - Bottom sheet pattern for modal dialogs
- **Skeleton** - Custom shimmer loading component (use instead of CircularProgressIndicator)
- **AnimeCard** - Standard card for grid/carousel layouts

## Code Conventions

### When Adding New Features

1. **API Services**: Follow stateless pattern, return Futures, throw exceptions on error
2. **Loading States**: Use skeleton widgets from [widgets/skeleton.dart](widgets/skeleton.dart), not CircularProgressIndicator
3. **Error Handling**: Catch exceptions in screens, show SnackBar or retry UI
4. **Images**: Use `CachedNetworkImage` with CORS proxy helper for web
5. **New Screens**: StatefulWidget with local state, manually instantiate needed services

### Model Classes

All models follow this pattern:
- Immutable fields (final)
- `fromJson` factory constructor
- No `toJson` (not needed - app is read-only)
- Some have `copyWith()` for immutable updates (e.g., Episode with thumbnails)

### Async Patterns

Critical data loading:
```dart
setState(() => _isLoading = true);
try {
  final data = await _service.getData();
  setState(() {
    _data = data;
    _isLoading = false;
  });
} catch (e) {
  setState(() {
    _error = e.toString();
    _isLoading = false;
  });
}
```

Background enrichment (non-critical):
```dart
try {
  final extra = await _service.getExtra();
  if (mounted) {
    setState(() => _extra = extra);
  }
} catch (e) {
  // Silent failure - enrichment is optional
}
```

## Testing Notes

- The app currently uses `flutter_test` package but has no test files
- Services are designed to be testable via constructor injection
- API services could be mocked by implementing same interface

## Platform-Specific Behavior

- **Portrait Lock**: App forces portrait orientation except VideoPlayerPage (landscape)
- **Fullscreen**: VideoPlayerPage hides system UI for immersive experience
- **CORS Proxy**: Web platform uses corsproxy.io for image loading
- **Cached Images**: Mobile/desktop cache images locally, web does not

## Known Patterns to Follow

When working with this codebase:

1. **Don't use global state** - Pass services through constructors
2. **Skeleton loaders** - Use themed skeleton widgets, not progress indicators
3. **Fail gracefully** - Enrichment APIs can fail without breaking UX
4. **Manual navigation** - Use MaterialPageRoute.push(), not named routes
5. **Service instantiation** - New in screen/widget, not singleton
6. **Theme integration** - Use `Theme.of(context).colorScheme` for colors
