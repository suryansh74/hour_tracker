# Hour Tracker

**Track what you do every hour — stay aware of how you spend your day.**

Hour Tracker is a simple offline app that asks you once an hour: *“What were you doing?”*  
You pick a category (Deep Work, Study, Exercise, …), optionally add a note, and move on. Over time you get a clear picture of your focus, distractions, and streaks.

No account. No cloud. Everything stays on your phone.

---

## Try it on Android

**Direct download (latest APK):**  
👉 **[Download Hour Tracker v1.0.3](https://github.com/suryansh74/hour_tracker/releases/download/v1.0.3/app-release.apk)**

Or open the [Releases page](https://github.com/suryansh74/hour_tracker/releases/latest) and tap **`app-release.apk`** under **Assets**.

> **Use v1.0.3 or newer.** Fixes startup freezes and makes hourly notification beeps reliable on Android.

### How to install
1. Download the APK on your Android phone  
2. If asked, allow **Install unknown apps** for your browser or file manager  
3. Open the downloaded file → **Install**  
4. Open **Hour Tracker** from your app drawer  

Installing over an older version usually keeps your data.

> **iOS / iPhone:** Not available yet. The current release is Android-only. An iOS version needs a Mac and an Apple Developer account to build.

---

## What the app does

| Feature | In plain words |
|--------|----------------|
| **Hourly reminders** | Beeps every hour (between the times you set as wake & sleep) so you log that slot |
| **Categories** | Tag hours as Deep Work, Study, Leisure, etc. — add your own colours too |
| **Today screen** | See today’s hours: logged, missed, or still ahead |
| **Dashboard** | Charts of where time went, a calendar heatmap, and a quiet “discipline” score |
| **History** | Scroll past days (read-only) |
| **Export** | Share a CSV of all your logs |
| **Privacy** | Fully offline. Nothing is uploaded |

---

## For developers (run from source)

If you want to build or change the code:

```bash
git clone https://github.com/suryansh74/hour_tracker.git
cd hour_tracker
flutter pub get
flutter run
```

**Build a release APK:**

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.x.

---

## Links

- **Android APK (v1.0.3):** [Download](https://github.com/suryansh74/hour_tracker/releases/download/v1.0.3/app-release.apk)  
- **Latest release:** https://github.com/suryansh74/hour_tracker/releases/latest  
- **All releases:** https://github.com/suryansh74/hour_tracker/releases  
- **Source code:** this repository  

---

## Privacy

All data is stored only on your device (`hour_tracker.db`).  
There is no login and no server.
