# Shia Companion

[![CI](https://github.com/saeedjassani/ShiaCompanion/actions/workflows/ci.yml/badge.svg)](https://github.com/saeedjassani/ShiaCompanion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

All the features needed by the lovers of Ahle Bayt (may Allah's peace and
blessings be upon them) in one app: duas, ziyarats, the Quran, prayer times and
more, free and without ads.

<p>
  <a href="https://play.google.com/store/apps/details?id=com.developer110.shiacompanion">Google Play</a> ·
  <a href="https://apps.apple.com/us/app/shia-ithna-ashari-companion/id1492517189">App Store</a> ·
  <a href="https://shia-companion.web.app/">Web</a>
</p>

## Features

- **Duas, Ziyarats, Munajat and Aamal**: a large library of Arabic text with
  transliteration and translation, audio recitations (streamed or downloaded
  for offline use), reading-progress tracking and shareable deep links.
- **Quran**: full text with translation, listen-and-follow recitation and a
  recitation tracker.
- **Prayer times and Hijri calendar**: location-based prayer times, azaan
  notifications, precise prayer alarms, home-screen widgets and an adjustable
  Hijri date with Islamic events.
- **Taqibaat and Namaz** guides, **Today's Recitations** for the day of the
  week, and **Zikr Reminders**.
- **Tools**: Qibla finder, tasbeeh counter, rakaat counter, qaza tracker and
  prayer times during flights.
- **Library**, hadith, favorites, playlists and personal reading stats, synced
  across devices when signed in.

## Tech stack

- [Flutter](https://flutter.dev) (Android, iOS and web from one codebase)
- Firebase: Authentication, Firestore, Realtime Database, Analytics,
  Crashlytics and Hosting (for the web app)
- Zikr content ships with the app as bundled assets (`assets/zikr.json` and
  `assets/zikr/<uid>`), so it works offline.

## Getting started

1. Install the Flutter version pinned in
   [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (`FLUTTER_VERSION`).
2. Clone and fetch dependencies:

   ```bash
   git clone https://github.com/saeedjassani/ShiaCompanion.git
   cd ShiaCompanion
   flutter pub get
   ```

3. Run it:

   ```bash
   flutter run            # on a connected device or emulator
   flutter run -d chrome  # the web app
   ```

Before opening a pull request, run the same checks CI does:

```bash
flutter analyze
flutter test
```

## Project layout

| Path | What's there |
| --- | --- |
| `lib/pages/` | Screens (zikr reader, Quran, calendar, settings, ...) |
| `lib/services/` | Prayer times, notifications, audio, sync, deep links, analytics |
| `lib/data/`, `lib/models/` | Data loading and models |
| `lib/widgets/` | Shared UI components |
| `assets/zikr.json`, `assets/zikr/` | The zikr index and one content file per zikr |
| `assets/quran/`, `assets/hadith/` | Quran and hadith text |
| `scripts/` | Content import, proofreading and maintenance scripts |
| `test/`, `integration_test/`, `test_visual/` | Unit/widget, integration and visual tests |
| `docs/` | CI/release pipeline, test plans and other notes |

## Contributing

Contributions are welcome, whether code, content corrections or ideas.

- **Found a mistake in a dua or ziyarat?** Use the in-app mistake report, or
  [open an issue](https://github.com/saeedjassani/ShiaCompanion/issues) with
  the title of the zikr and what's wrong.
- **Bugs and feature requests**: please
  [open an issue](https://github.com/saeedjassani/ShiaCompanion/issues).
- **Code**: fork the repo, make your change on a branch, make sure
  `flutter analyze` and `flutter test` pass, and open a pull request against
  `master`.
- **Content changes**: keep a zikr's title in `assets/zikr.json` and its
  `assets/zikr/<uid>` file in sync, and never change an existing `slug` (old
  links depend on it). See [`CLAUDE.md`](CLAUDE.md) for the title style guide.

See [`docs/CI.md`](docs/CI.md) for how CI and releases work.

## Contact

Questions or feedback: [developer110@hotmail.com](mailto:developer110@hotmail.com)

## License

[MIT](LICENSE)
