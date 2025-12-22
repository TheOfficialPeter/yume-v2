import 'dart:async';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:video_player/video_player.dart';

import '../models/episode.dart';
import '../models/episode_server.dart';
import '../models/skip_time.dart';
import '../models/streaming_source.dart' as models;
import '../services/aniskip_service.dart';
import '../services/hianime_service.dart';
import '../services/theme_provider.dart';
import '../services/watch_progress_provider.dart';
import '../services/watch_progress_service.dart';

class VideoPlayerPage extends StatefulWidget {
  final String animeId;
  final String animeTitle;
  final String? posterUrl;
  final Episode episode;
  final String serverName;
  final String category;
  final double? initialPositionSeconds;

  const VideoPlayerPage({
    super.key,
    required this.animeId,
    required this.animeTitle,
    this.posterUrl,
    required this.episode,
    required this.serverName,
    required this.category,
    this.initialPositionSeconds,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final _hiAnimeService = HiAnimeService();
  final _aniSkipService = AniSkipService();
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  SkipTimesResponse? _skipTimes;
  SkipTimeResult? _currentSkipSection;
  bool _hasAutoSkippedCurrentSection = false;
  WatchProgressService? _watchProgressService;
  Timer? _progressTimer;
  bool _showRewindIndicator = false;
  bool _showForwardIndicator = false;
  Timer? _rewindIndicatorTimer;
  Timer? _forwardIndicatorTimer;
  late final Stream<NativeDeviceOrientation> _orientationStream;
  int _lastLandscapeQuarterTurns = 0;
  late Episode _currentEpisode;
  late String _currentServerName;
  late String _currentCategory;
  bool _isAutoplayLoadingNextEpisode = false;
  bool _hasHandledEpisodeCompletion = false;
  List<Episode>? _episodeCache;
  Future<List<Episode>>? _episodesFuture;
  double? _pendingInitialPositionSeconds;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentServerName = widget.serverName;
    _currentCategory = widget.category;
    _pendingInitialPositionSeconds = widget.initialPositionSeconds;
    // Start in landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for immersive fullscreen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _orientationStream = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true);
    _initializePlayer(startAtSeconds: _pendingInitialPositionSeconds);
  }

  @override
  void dispose() {
    _persistProgressOnExit();
    _disposeVideoControllers();
    _progressTimer?.cancel();
    _rewindIndicatorTimer?.cancel();
    _forwardIndicatorTimer?.cancel();
    // Restore portrait-only orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _disposeVideoControllers() {
    _videoPlayerController?.removeListener(_handleVideoTick);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchProgressService ??= WatchProgressProvider.of(context);
  }

  Future<List<Subtitle>?> _fetchSubtitles(
    List<models.Subtitle> subtitles,
  ) async {
    try {
      // Get English subtitle or first available
      final subtitle = subtitles.firstWhere(
        (s) => s.lang.toLowerCase().contains('english'),
        orElse: () => subtitles.first,
      );

      final response = await http.get(Uri.parse(subtitle.url));

      if (response.statusCode == 200) {
        return _parseVttSubtitles(response.body);
      }
    } catch (e) {
      // Silently fail - subtitles are optional
    }
    return null;
  }

  List<Subtitle> _parseVttSubtitles(String vttContent) {
    final List<Subtitle> subtitles = [];
    final lines = vttContent.split('\n');

    int index = 0;
    Duration? start;
    Duration? end;
    String text = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip WEBVTT header and empty lines at start
      if (line.isEmpty ||
          line.startsWith('WEBVTT') ||
          line.startsWith('Kind:') ||
          line.startsWith('Language:')) {
        continue;
      }

      // Check if line contains timestamp (e.g., "00:00:01.000 --> 00:00:03.000")
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          start = _parseVttTimestamp(parts[0].trim());
          end = _parseVttTimestamp(parts[1].trim());
        }
      } else if (start != null && end != null && line.isNotEmpty) {
        // This is subtitle text
        if (text.isNotEmpty) text += '\n';
        text += line;

        // Check if next line is empty or contains timestamp (end of this subtitle)
        if (i + 1 >= lines.length ||
            lines[i + 1].trim().isEmpty ||
            lines[i + 1].contains('-->')) {
          subtitles.add(
            Subtitle(index: index++, start: start, end: end, text: text),
          );
          start = null;
          end = null;
          text = '';
        }
      }
    }

    return subtitles;
  }

  Duration _parseVttTimestamp(String timestamp) {
    // Parse timestamp like "00:00:01.000" or "01:23:45.678"
    final parts = timestamp.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsParts = parts[2].split('.');
      final seconds = int.parse(secondsParts[0]);
      final milliseconds =
          secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    }
    return Duration.zero;
  }

  void _checkSkipSection() {
    if (_skipTimes == null || !_skipTimes!.found) return;
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final position = _videoPlayerController!.value.position.inSeconds.toDouble();

    // Check if we're in any skip section
    SkipTimeResult? newSkipSection;
    for (final result in _skipTimes!.results) {
      if (position >= result.interval.startTime && position <= result.interval.endTime) {
        newSkipSection = result;
        break;
      }
    }

    // Check if skip section changed
    if (newSkipSection != _currentSkipSection) {
      final oldSection = _currentSkipSection;

      setState(() {
        _currentSkipSection = newSkipSection;
      });

      // Reset auto-skip flag when exiting a section
      if (newSkipSection == null) {
        _hasAutoSkippedCurrentSection = false;
      }
      // Auto-skip when entering a new section (if enabled)
      else if (oldSection == null || oldSection.skipId != newSkipSection.skipId) {
        _hasAutoSkippedCurrentSection = false;
        _autoSkipIfEnabled();
      }
    }
  }

  void _autoSkipIfEnabled() {
    // Get auto-skip preference from ThemeProvider
    final themeService = ThemeProvider.of(context);
    if (themeService == null) return;

    // Only auto-skip once per section and if enabled
    if (themeService.autoSkipEnabled && !_hasAutoSkippedCurrentSection) {
      _hasAutoSkippedCurrentSection = true;
      _skipToEnd(isAutoSkip: true);
    }
  }

  void _skipToEnd({bool isAutoSkip = false}) {
    if (_currentSkipSection == null || _videoPlayerController == null) return;

    // Skip to 1 second after the end of the skip section to avoid re-triggering
    final controller = _videoPlayerController!;
    final endTime = _currentSkipSection!.interval.endTime + 1.0;
    final durationMs = controller.value.duration.inMilliseconds;
    final targetMs = (endTime * 1000).round();
    final cappedMs = math.min(targetMs, durationMs);
    final skipToPosition = Duration(milliseconds: cappedMs);
    _videoPlayerController!.seekTo(skipToPosition);

    setState(() {
      _currentSkipSection = null;
    });
  }

  bool _seekRelative(Duration offset) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return false;
    final current = controller.value.position;
    final duration = controller.value.duration;

    var target = current + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (target > duration) {
      target = duration;
    }
    controller.seekTo(target);
    return true;
  }

  void _showIndicator({
    required bool forward,
    required bool visible,
  }) {
    if (!mounted) return;
    setState(() {
      if (forward) {
        _showForwardIndicator = visible;
      } else {
        _showRewindIndicator = visible;
      }
    });
  }

  void _triggerIndicatorTimer({required bool forward}) {
    final timer = Timer(const Duration(milliseconds: 600), () {
      _showIndicator(forward: forward, visible: false);
    });
    if (forward) {
      _forwardIndicatorTimer?.cancel();
      _forwardIndicatorTimer = timer;
    } else {
      _rewindIndicatorTimer?.cancel();
      _rewindIndicatorTimer = timer;
    }
  }

  void _handleDoubleTapRewind() {
    final didSeek = _seekRelative(const Duration(seconds: -10));
    if (!didSeek) return;
    _showIndicator(forward: false, visible: true);
    _triggerIndicatorTimer(forward: false);
  }

  void _handleDoubleTapForward() {
    final didSeek = _seekRelative(const Duration(seconds: 10));
    if (!didSeek) return;
    _showIndicator(forward: true, visible: true);
    _triggerIndicatorTimer(forward: true);
  }

  Future<void> _fetchSkipTimes(int malId, int episodeNumber) async {
    try {
      final skipTimes = await _aniSkipService.getSkipTimes(
        malId,
        episodeNumber,
      );

      if (mounted && skipTimes != null && skipTimes.found) {
        setState(() {
          _skipTimes = skipTimes;
        });
      }
    } catch (e) {
      // Silently fail - skip times are not critical
    }
  }

  Future<void> _initializePlayer({double? startAtSeconds}) async {
    _progressTimer?.cancel();
    final effectiveStartSeconds = startAtSeconds ?? _pendingInitialPositionSeconds;
    _pendingInitialPositionSeconds = null;

    setState(() {
      _isLoading = true;
      _error = null;
      _skipTimes = null;
      _currentSkipSection = null;
      _hasAutoSkippedCurrentSection = false;
    });

    _disposeVideoControllers();

    try {
      // Fetch streaming sources
      final streamingData = await _hiAnimeService.getStreamingSources(
        _currentEpisode.episodeId,
        server: _currentServerName,
        category: _currentCategory,
      );

      if (streamingData.sources.isEmpty) {
        throw Exception('No streaming sources available');
      }

      // Fetch skip times in the background if MAL ID is available
      if (streamingData.malID != null) {
        _fetchSkipTimes(streamingData.malID!, _currentEpisode.number);
      }

      // Get the first M3U8 source or first available source
      final source = streamingData.sources.firstWhere(
        (s) => s.isM3U8,
        orElse: () => streamingData.sources.first,
      );

      // Initialize video player with HLS support
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        httpHeaders: streamingData.headers,
      );

      await _videoPlayerController!.initialize();

      if (effectiveStartSeconds != null && effectiveStartSeconds > 0) {
        final target = Duration(
          milliseconds: (effectiveStartSeconds * 1000).round(),
        );
        await _videoPlayerController!.seekTo(target);
      }

      // Add listener for checking skip sections and autoplay
      _videoPlayerController!.addListener(_handleVideoTick);

      // Fetch and parse subtitles
      List<Subtitle>? parsedSubtitles;
      if (streamingData.subtitles.isNotEmpty) {
        parsedSubtitles = await _fetchSubtitles(streamingData.subtitles);
      }

      // Configure Chewie with mobile-optimized controls and subtitles
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        // Subtitle support
        subtitle: parsedSubtitles != null && parsedSubtitles.isNotEmpty
            ? Subtitles(parsedSubtitles)
            : null,
        subtitleBuilder: parsedSubtitles != null && parsedSubtitles.isNotEmpty
            ? (context, subtitle) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
            : null,
        // Mobile optimized controls
        allowFullScreen: false, // Already fullscreen
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: true,
        autoInitialize: true,
        hideControlsTimer: const Duration(seconds: 3),
        // Material design controls
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white70,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasHandledEpisodeCompletion = false;
        });
        _startProgressUpdates();
        unawaited(_ensureEpisodesCached());
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

  void _handleVideoTick() {
    _checkSkipSection();
    _maybeTriggerAutoplay();
  }

  void _maybeTriggerAutoplay() {
    if (_hasHandledEpisodeCompletion || _isAutoplayLoadingNextEpisode) return;
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isCompleted) return;
    _hasHandledEpisodeCompletion = true;
    _handleEpisodeCompletion();
  }

  void _handleEpisodeCompletion() {
    _watchProgressService?.markEpisodeFinished(
      animeId: widget.animeId,
      animeTitle: widget.animeTitle,
      posterUrl: widget.posterUrl,
      episodeId: _currentEpisode.episodeId,
      episodeNumber: _currentEpisode.number,
      serverName: _currentServerName,
      category: _currentCategory,
    );
    _startAutoplayForNextEpisode();
  }

  Future<void> _startAutoplayForNextEpisode() async {
    if (!mounted || _isAutoplayLoadingNextEpisode) return;
    setState(() {
      _isAutoplayLoadingNextEpisode = true;
    });

    try {
      final config = await _buildNextPlaybackConfig();
      if (!mounted) return;

      if (config == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Next episode is not available yet.')),
        );
        return;
      }

      _currentEpisode = config.episode;
      _currentServerName = config.serverName;
      _currentCategory = config.category;
      await _initializePlayer(startAtSeconds: 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start next episode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAutoplayLoadingNextEpisode = false;
        });
      }
    }
  }

  Future<_NextPlaybackConfig?> _buildNextPlaybackConfig() async {
    final nextEpisodeNumber = _currentEpisode.number + 1;
    final nextEpisode = await _episodeForNumber(nextEpisodeNumber);
    if (nextEpisode == null) return null;

    final servers = await _hiAnimeService.getEpisodeServers(nextEpisode.episodeId);
    final serverChoice = _selectServerForAutoplay(servers);
    if (serverChoice == null) return null;

    return _NextPlaybackConfig(
      episode: nextEpisode,
      serverName: serverChoice.serverName,
      category: serverChoice.category,
    );
  }

  Future<Episode?> _episodeForNumber(int episodeNumber) async {
    final episodes = await _ensureEpisodesCached();
    for (final episode in episodes) {
      if (episode.number == episodeNumber) {
        return episode;
      }
    }
    return null;
  }

  Future<List<Episode>> _ensureEpisodesCached() async {
    if (_episodeCache != null) return _episodeCache!;
    _episodesFuture ??= _hiAnimeService.getAnimeEpisodes(widget.animeId);
    try {
      final episodes = await _episodesFuture!;
      _episodeCache = episodes;
      _watchProgressService?.cacheEpisodes(widget.animeId, episodes);
      return episodes;
    } finally {
      _episodesFuture = null;
    }
  }

  _ServerChoice? _selectServerForAutoplay(EpisodeServers servers) {
    final preferenceOrder = _categoryPreferenceOrder();
    final seenCategories = <String>{};

    for (final category in preferenceOrder) {
      if (seenCategories.contains(category)) continue;
      seenCategories.add(category);
      final server = _pickServerForCategory(servers, category);
      if (server != null) {
        return _ServerChoice(serverName: server.serverName, category: category);
      }
    }

    // Absolute fallback: try any remaining category with servers
    for (final category in ['sub', 'dub', 'raw']) {
      if (seenCategories.contains(category)) continue;
      final server = _pickServerForCategory(servers, category);
      if (server != null) {
        return _ServerChoice(serverName: server.serverName, category: category);
      }
    }
    return null;
  }

  List<String> _categoryPreferenceOrder() {
    final preferences = <String>[];
    preferences.add(_currentCategory);
    if (_currentCategory == 'dub') {
      preferences.addAll(['sub', 'raw']);
    } else if (_currentCategory == 'sub') {
      preferences.addAll(['dub', 'raw']);
    } else {
      preferences.addAll(['sub', 'dub', 'raw']);
    }
    return preferences;
  }

  EpisodeServer? _pickServerForCategory(EpisodeServers servers, String category) {
    final candidates = _serversForCategory(servers, category);
    if (candidates.isEmpty) return null;
    for (final server in candidates) {
      if (server.serverName == _currentServerName) {
        return server;
      }
    }
    return candidates.first;
  }

  List<EpisodeServer> _serversForCategory(EpisodeServers servers, String category) {
    switch (category) {
      case 'dub':
        return servers.dub;
      case 'raw':
        return servers.raw;
      case 'sub':
      default:
        return servers.sub;
    }
  }

  void _startProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncProgress();
    });
    _syncProgress();
  }

  void _syncProgress() {
    if (!mounted) return;
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inSeconds.toDouble();
    if (duration <= 0) return;
    final position = controller.value.position.inSeconds.toDouble();
    if (position < 0) return;

    _watchProgressService?.updateProgress(
      animeId: widget.animeId,
      animeTitle: widget.animeTitle,
      posterUrl: widget.posterUrl,
      episodeId: _currentEpisode.episodeId,
      episodeNumber: _currentEpisode.number,
      positionSeconds: position,
      durationSeconds: duration,
      serverName: _currentServerName,
      category: _currentCategory,
    );
  }

  void _persistProgressOnExit() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inSeconds.toDouble();
    if (duration <= 0) return;
    final position = controller.value.position.inSeconds.toDouble();
    final isCompleted =
        controller.value.isCompleted || (position / duration) >= 0.9;

    if (isCompleted) {
      _watchProgressService?.markEpisodeFinished(
        animeId: widget.animeId,
        animeTitle: widget.animeTitle,
        posterUrl: widget.posterUrl,
        episodeId: _currentEpisode.episodeId,
        episodeNumber: _currentEpisode.number,
        serverName: _currentServerName,
        category: _currentCategory,
      );
    } else {
      _watchProgressService?.updateProgress(
        animeId: widget.animeId,
        animeTitle: widget.animeTitle,
        posterUrl: widget.posterUrl,
        episodeId: _currentEpisode.episodeId,
        episodeNumber: _currentEpisode.number,
        positionSeconds: position,
        durationSeconds: duration,
        serverName: _currentServerName,
        category: _currentCategory,
      );
    }
  }

  Widget _buildPlayerStack(BuildContext context) {
    return Stack(
      children: [
        Chewie(controller: _chewieController!),
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: _handleDoubleTapRewind,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: _handleDoubleTapForward,
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedOpacity(
              opacity: _showRewindIndicator ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: _showForwardIndicator ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        if (_currentSkipSection != null)
          Positioned(
            bottom: 80,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _skipToEnd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip ${_currentSkipSection!.displayName}',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.fast_forward,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _quarterTurnsForOrientation(NativeDeviceOrientation? orientation) {
    if (orientation == NativeDeviceOrientation.landscapeRight) {
      _lastLandscapeQuarterTurns = 2;
    } else if (orientation == NativeDeviceOrientation.landscapeLeft) {
      _lastLandscapeQuarterTurns = 0;
    }
    return _lastLandscapeQuarterTurns;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<NativeDeviceOrientation>(
        stream: _orientationStream,
        initialData: NativeDeviceOrientation.landscapeLeft,
        builder: (context, snapshot) {
          final quarterTurns = _quarterTurnsForOrientation(snapshot.data);
          Widget content;

          if (_isLoading) {
            content = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Loading episode ${_currentEpisode.number}...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          } else if (_error != null) {
            content = Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _initializePlayer,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          } else if (_chewieController != null &&
              _chewieController!.videoPlayerController.value.isInitialized) {
            content = _buildPlayerStack(context);
          } else {
            content = const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          if (quarterTurns == 0) return content;
          return RotatedBox(
            quarterTurns: quarterTurns,
            child: content,
          );
        },
      ),
    );
  }
}

class _ServerChoice {
  final String serverName;
  final String category;

  const _ServerChoice({
    required this.serverName,
    required this.category,
  });
}

class _NextPlaybackConfig {
  final Episode episode;
  final String serverName;
  final String category;

  const _NextPlaybackConfig({
    required this.episode,
    required this.serverName,
    required this.category,
  });
}
