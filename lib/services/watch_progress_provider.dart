import 'package:flutter/material.dart';

import 'watch_progress_service.dart';

class WatchProgressProvider extends InheritedWidget {
  final WatchProgressService watchProgressService;

  const WatchProgressProvider({
    super.key,
    required this.watchProgressService,
    required super.child,
  });

  static WatchProgressService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WatchProgressProvider>()
        ?.watchProgressService;
  }

  @override
  bool updateShouldNotify(WatchProgressProvider oldWidget) {
    return watchProgressService != oldWidget.watchProgressService;
  }
}
