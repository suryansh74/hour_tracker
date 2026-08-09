# Hour Tracker

Offline-first Flutter productivity tracker that logs your activity every hour with reminders, analytics dashboards, calendar heatmaps, and CSV export.

## Features

- **Hourly logging** — Beeps every hour between your wake and sleep times so you can quickly tag what you did.
- **Categories** — Custom categories with a 20-colour palette plus a full HSV custom colour picker.
- **Dashboard** — Discipline score, lifetime missed hours, time-by-category pie chart, daily bar chart, and a 6-month calendar heatmap.
- **History** — Browse every past day from the day you installed the app (read-only).
- **Data control**
  - Delete a category and all hours logged under it are removed completely (no leftover “Unknown” entries).
  - Flexible date-range cleanup: pick any range between your install date and yesterday via a calendar picker.
- **Export** — Share a CSV of all logged hours.
- **Themes** — Light, dark, or system.
- **Fully offline** — Data lives in a local SQLite database (sqflite). No account required.

## Download (Android)

Published APKs (when available) are on the **[Releases](https://github.com/suryansh74/hour_tracker/releases)** page.

1. Open the latest release
2. Download `app-release.apk`
3. On your phone, allow **Install from unknown sources** for your browser/file manager
4. Open the APK and install

> **iOS:** Building an installable IPA requires a Mac + Apple Developer account. Use Xcode/`flutter build ipa` on a Mac if you need an iOS build.

## Screens

| Screen | Purpose |
|--------|---------|
| **Today** | Log each hour of the current day |
| **Dashboard** | Charts, scores, heatmap |
| **History** | Past days (read-only) |
| **Settings** | Wake/sleep window, categories, theme, notifications, data cleanup |

## Getting started (developers)

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.x (SDK `>=3.0.0 <4.0.0`)

### Run

```bash
git clone https://github.com/suryansh74/hour_tracker.git
cd hour_tracker
flutter pub get
flutter run
```

### Build release APK

```bash
flutter pub get
# (optional) regenerate icons after changing assets/icon/app_icon.png
dart run flutter_launcher_icons
flutter build apk --release
```

APK output:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Publish APK on GitHub Releases

1. Build the APK (command above)
2. Go to https://github.com/suryansh74/hour_tracker/releases/new
3. Create a tag e.g. `v1.0.0`
4. Attach `app-release.apk`
5. Publish

### Platforms

Android, iOS, macOS, Windows, Linux, and Web (via Flutter).

## Project structure

```
lib/
  main.dart
  models/          # TrackCategory, HourEntry
  providers/       # AppState (ChangeNotifier)
  screens/         # Today, Dashboard, History, Settings, Root
  services/        # SQLite (DatabaseService), notifications
  theme/
  widgets/         # Calendar heatmap, log-entry bottom sheet
assets/
  icon/            # App launcher icon source
```

## Data & privacy

- Everything is stored locally on device (`hour_tracker.db`).
- Nothing is uploaded or synced to a server.
- You can export CSV or permanently delete any date range from Settings.

## Licence

Private / personal use unless otherwise stated by the author.
