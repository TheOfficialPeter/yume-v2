import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/watch_progress_provider.dart';

class SettingsPage extends StatelessWidget {
  final ThemeService themeService;

  const SettingsPage({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Appearance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme Mode'),
          subtitle: Text(_getThemeModeLabel(themeService.themeMode)),
          onTap: () => _showThemeModeDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Color Scheme'),
          subtitle: const Text('Customize app colors'),
          onTap: () => _showColorSchemeDialog(context),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Video Playback',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.skip_next_outlined),
          title: const Text('Auto-Skip Intro/Outro'),
          subtitle: const Text('Automatically skip opening and ending sequences'),
          value: themeService.autoSkipEnabled,
          onChanged: (value) {
            themeService.setAutoSkipEnabled(value);
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'History',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear Continue Watching'),
          subtitle: const Text('Remove saved watch progress across all anime'),
          onTap: () => _confirmClearWatchHistory(context),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'About',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('App Info'),
          subtitle: Text('Version 2.0.0'),
        ),
      ],
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Mode'),
        content: RadioGroup<ThemeMode>(
          groupValue: themeService.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeService.setThemeMode(value);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Light'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.light,
                ),
                onTap: () {
                  themeService.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Dark'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                ),
                onTap: () {
                  themeService.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('System default'),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.system,
                ),
                onTap: () {
                  themeService.setThemeMode(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorSchemeDialog(BuildContext context) {
    final colors = [
      {'name': 'Blue', 'color': Colors.blue, 'isEasterEgg': false},
      {'name': 'Purple', 'color': Colors.purple, 'isEasterEgg': false},
      {'name': 'Teal', 'color': Colors.teal, 'isEasterEgg': false},
      {'name': 'Orange', 'color': Colors.deepOrange, 'isEasterEgg': false},
      {'name': 'Pink', 'color': Colors.pink, 'isEasterEgg': false},
      {'name': 'Green', 'color': Colors.green, 'isEasterEgg': false},
      {'name': 'Black & White', 'color': const Color(0xFF101010), 'isEasterEgg': false},
      {'name': 'Secret', 'color': const Color(0xFF6A1B9A), 'isEasterEgg': true},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color Scheme'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final colorData = colors[index];
              final color = colorData['color'] as Color;
              final isEasterEgg = colorData['isEasterEgg'] as bool;
              final isSelected = color == themeService.seedColor;

              return InkWell(
                onTap: () {
                  themeService.setSeedColor(color);
                  if (isEasterEgg) {
                    themeService.setEasterEggMode(true);
                  } else {
                    themeService.setEasterEggMode(false);
                  }
                  Navigator.pop(context);
                },
                child: isEasterEgg
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: color, width: 3)
                              : Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 1),
                        ),
                        child: ClipOval(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: const Center(
                                    child: Icon(Icons.check,
                                        color: Colors.white, size: 24),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmClearWatchHistory(BuildContext context) {
    final watchProgressService = WatchProgressProvider.of(context);
    if (watchProgressService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watch history service unavailable')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Continue Watching?'),
        content: const Text(
          'This will remove your entire watch history and reset the Continue Watching section. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              await watchProgressService.clearAll();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Watch history cleared')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
