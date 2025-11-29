import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_page.dart';
import 'services/theme_service.dart';
import 'services/theme_provider.dart';
import 'services/saved_anime_service.dart';
import 'services/saved_anime_provider.dart';
import 'services/watch_progress_service.dart';
import 'services/watch_progress_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Lock app to portrait mode (video player overrides this)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final themeService = ThemeService();
  await themeService.init();

  final savedAnimeService = SavedAnimeService();
  await savedAnimeService.init();

  final watchProgressService = WatchProgressService();
  await watchProgressService.init();

  runApp(MyApp(
    themeService: themeService,
    savedAnimeService: savedAnimeService,
    watchProgressService: watchProgressService,
  ));
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;
  final SavedAnimeService savedAnimeService;
  final WatchProgressService watchProgressService;

  const MyApp({
    super.key,
    required this.themeService,
    required this.savedAnimeService,
    required this.watchProgressService,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeService: themeService,
      child: WatchProgressProvider(
        watchProgressService: watchProgressService,
        child: SavedAnimeProvider(
          savedAnimeService: savedAnimeService,
          child: ListenableBuilder(
            listenable: themeService,
            builder: (context, child) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Yume',
                theme: themeService.getLightTheme(),
                darkTheme: themeService.getDarkTheme(),
                themeMode: themeService.themeMode,
                home: HomePage(
                  title: 'Yume',
                  themeService: themeService,
                  savedAnimeService: savedAnimeService,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
