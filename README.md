# Yume

A clean anime streaming app built with Flutter.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)

## Features

- Browse trending, top airing, and popular anime
- Search and filter by genre/category
- HLS streaming with subtitle support
- Multiple server fallbacks
- Light/dark themes with 24 color options

## Setup

```bash
git clone https://github.com/yourusername/yume.git
cd yume
flutter pub get
```

Create `.env`:
```
HIANIME_API_URL=http://localhost:4000
```

Requires [aniwatch-api](https://github.com/ghoshRitesh12/aniwatch-api) running as backend.

## Run

```bash
flutter run
```

## Build

```bash
flutter build apk --release    # Android
flutter build ios --release    # iOS
```

## Stack

Flutter, Chewie, Material Design 3, HiAnime API, AniList API
