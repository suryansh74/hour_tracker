import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/hour_entry.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final _db = DatabaseService.instance;
  final _dateFmt = DateFormat('yyyy-MM-dd');

  List<TrackCategory> categories = [];
  Map<int, HourEntry> todaysEntries = {}; // hour -> entry
  int wakeHour = 6;
  int sleepHour = 23;
  /// How often to beep inside the active window (minutes). Default 60 = hourly.
  int beepIntervalMinutes = 60;
  ThemeMode themeMode = ThemeMode.system;
  DateTime installDate = DateTime.now();

  /// Incremented whenever entries are bulk-deleted (category wipe or old-data
  /// cleanup) so screens that use FutureBuilder can detect stale futures.
  int dataGeneration = 0;

  bool _initialized = false;
  bool get initialized => _initialized;

  String get todayKey => _dateFmt.format(DateTime.now());

  Future<void> init() async {
    categories = await _db.getCategories();

    final wake = await _db.getSetting('wakeHour');
    final sleep = await _db.getSetting('sleepHour');
    wakeHour = wake != null ? int.parse(wake) : 6;
    sleepHour = sleep != null ? int.parse(sleep) : 23;

    final interval = await _db.getSetting('beepIntervalMinutes');
    beepIntervalMinutes = interval != null ? int.parse(interval) : 60;
    // Drop old debug intervals (1–5 min) so production defaults to hourly.
    if (beepIntervalMinutes < 15) {
      beepIntervalMinutes = 60;
      await _db.setSetting('beepIntervalMinutes', '60');
    }

    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode');
    themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    var installDateStr = await _db.getSetting('installDate');
    if (installDateStr == null) {
      installDateStr = todayKey;
      await _db.setSetting('installDate', installDateStr);
    }
    installDate = _dateFmt.parse(installDateStr);

    await _loadTodaysEntries();

    // Do NOT schedule notifications here — that needs runtime permissions and
    // can hang on some Android devices, leaving the user on a forever spinner.
    // main.dart schedules beeps after init + permission prompts.
    _initialized = true;
    notifyListeners();
  }

  /// Used if init() throws so the UI is never stuck on the loading spinner.
  void forceInitialized() {
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadTodaysEntries() async {
    final list = await _db.getEntriesForDate(todayKey);
    todaysEntries = {for (final e in list) e.hour: e};
  }

  // ---------------- Logging ----------------

  Future<void> logHour({required int hour, required int categoryId, String note = ''}) async {
    final entry = HourEntry(
      date: todayKey,
      hour: hour,
      categoryId: categoryId,
      note: note,
      loggedAt: DateTime.now().toIso8601String(),
    );
    await _db.upsertEntry(entry);
    todaysEntries[hour] = entry;
    notifyListeners();
  }

  Future<void> deleteHourEntry(int hour) async {
    await _db.deleteEntry(todayKey, hour);
    todaysEntries.remove(hour);
    notifyListeners();
  }

  /// Active (non-sleep) hours for "today" that have already occurred,
  /// i.e. the slots the user is expected to have logged by now.
  List<int> get pastActiveHoursToday {
    final nowHour = DateTime.now().hour;
    return activeHoursList.where((h) => h < nowHour).toList();
  }

  List<int> get activeHoursList {
    if (wakeHour < sleepHour) {
      return [for (var h = wakeHour; h < sleepHour; h++) h];
    }
    return [
      for (var h = wakeHour; h < 24; h++) h,
      for (var h = 0; h < sleepHour; h++) h,
    ];
  }

  // ---------------- Settings ----------------

  Future<void> updateSleepWindow({required int newWake, required int newSleep}) async {
    wakeHour = newWake;
    sleepHour = newSleep;
    await _db.setSetting('wakeHour', newWake.toString());
    await _db.setSetting('sleepHour', newSleep.toString());
    await _rescheduleBeeps();
    notifyListeners();
  }

  Future<void> updateBeepInterval(int minutes) async {
    beepIntervalMinutes = minutes.clamp(1, 24 * 60);
    await _db.setSetting('beepIntervalMinutes', beepIntervalMinutes.toString());
    await _rescheduleBeeps();
    notifyListeners();
  }

  Future<void> _rescheduleBeeps() async {
    try {
      await NotificationService.instance.scheduleBeeps(
        wakeHour: wakeHour,
        sleepHour: sleepHour,
        intervalMinutes: beepIntervalMinutes,
      );
    } catch (_) {
      // Non-fatal
    }
  }

  String get beepIntervalLabel {
    final m = beepIntervalMinutes;
    if (m < 60) return 'Every $m min';
    if (m == 60) return 'Every 1 hour';
    if (m % 60 == 0) return 'Every ${m ~/ 60} hours';
    return 'Every $m min';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> addCategory(String name, int colorValue) async {
    final id = await _db.insertCategory(TrackCategory(name: name, colorValue: colorValue));
    categories = await _db.getCategories();
    notifyListeners();
    // silence unused var warning if analyzer configured strictly
    // ignore: unnecessary_statements
    id;
  }

  Future<void> updateCategory(TrackCategory category) async {
    await _db.updateCategory(category);
    categories = await _db.getCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    // Entries that used this category were removed in the DB layer.
    // Refresh today's map so the home screen / dashboard drop them immediately.
    await _loadTodaysEntries();
    categories = await _db.getCategories();
    // Bump a generation so FutureBuilders on dashboard re-run their queries.
    dataGeneration++;
    notifyListeners();
  }

  TrackCategory? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------------- Analytics ----------------

  Future<Map<String, List<HourEntry>>> entriesGroupedByDate(String start, String end) async {
    final list = await _db.getEntriesForRange(start, end);
    final map = <String, List<HourEntry>>{};
    for (final e in list) {
      map.putIfAbsent(e.date, () => []).add(e);
    }
    return map;
  }

  /// Consecutive days (ending yesterday or today) where the user logged
  /// at least [threshold] fraction of that day's active hours.
  Future<int> currentStreak({double threshold = 0.8}) async {
    final today = DateTime.now();
    var streak = 0;
    for (var i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      final key = _dateFmt.format(day);
      final entries = await _db.getEntriesForDate(key);
      final expected = activeHoursList.length;
      // For "today" only count hours that have already passed.
      final applicable = i == 0 ? pastActiveHoursToday.length : expected;
      if (applicable == 0) {
        if (i == 0) continue; // too early in the day to break the streak
        break;
      }
      final ratio = entries.length / applicable;
      if (ratio >= threshold) {
        streak++;
      } else {
        if (i == 0) continue; // don't kill streak for an unfinished today
        break;
      }
    }
    return streak;
  }

  /// Today's completion ratio so far (0.0-1.0), based on active hours that
  /// have already passed. Used to show a live "discipline score".
  double get todayDisciplineRatio {
    final applicable = pastActiveHoursToday.length;
    if (applicable == 0) return 1.0;
    final logged = pastActiveHoursToday.where((h) => todaysEntries.containsKey(h)).length;
    return logged / applicable;
  }

  /// Total hours across all PAST days (not today — today can still be
  /// fixed) that were never logged. This number only ever grows; it's the
  /// permanent cost of skipping a beep, by design.
  Future<int> lifetimeMissedHours() async {
    final today = DateTime.now();
    final daysSinceInstall = today.difference(installDate).inDays;
    var missed = 0;
    final expected = activeHoursList.length;
    for (var i = 1; i <= daysSinceInstall; i++) {
      final day = today.subtract(Duration(days: i));
      final key = _dateFmt.format(day);
      final entries = await _db.getEntriesForDate(key);
      final gap = expected - entries.length;
      missed += gap > 0 ? gap : 0;
    }
    return missed;
  }

  /// A soft, slow-moving "discipline score" (0-100) built from the last
  /// 60 days (or fewer, if the app is newer than that). Consistent days
  /// nudge it up, bad days nudge it down — gently, not a cliff-edge.
  /// This is meant to be a quiet number to notice trends in, not a
  /// scoreboard to feel bad about.
  Future<int> disciplineScore() async {
    final today = DateTime.now();
    final daysSinceInstall = today.difference(installDate).inDays;
    final lookback = daysSinceInstall.clamp(0, 60);
    if (lookback == 0) return 100; // brand new install, no history yet to judge

    final expected = activeHoursList.length;
    double score = 70; // neutral starting point

    for (var i = lookback; i >= 1; i--) {
      final day = today.subtract(Duration(days: i));
      final key = _dateFmt.format(day);
      final entries = await _db.getEntriesForDate(key);
      final ratio = expected == 0 ? 1.0 : entries.length / expected;

      if (ratio >= 0.8) {
        score = (score + 1.5).clamp(0, 100);
      } else if (ratio >= 0.5) {
        score = (score - 1).clamp(0, 100);
      } else {
        score = (score - 2.5).clamp(0, 100);
      }
    }
    return score.round();
  }

  // ---------------- History (read-only past days) ----------------

  /// Every day from install date up to (and including) yesterday, most
  /// recent first — including fully-missed days, so a skipped day shows
  /// up as a visible gap in history rather than silently disappearing.
  /// Today is intentionally excluded; it belongs on the Today screen
  /// where it's still editable.
  Future<List<String>> historyDateKeys() async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (yesterday.isBefore(installDate)) return [];
    final totalDays = yesterday.difference(installDate).inDays + 1;
    return List.generate(totalDays, (i) => _dateFmt.format(yesterday.subtract(Duration(days: i))));
  }

  Future<List<HourEntry>> entriesForHistoryDate(String date) => _db.getEntriesForDate(date);

  // ---------------- Data management ----------------

  /// Deletes all entries strictly before [cutoff]. Returns rows deleted.
  Future<int> deleteDataBefore(DateTime cutoff) async {
    final count = await _db.deleteEntriesBefore(_dateFmt.format(cutoff));
    await _loadTodaysEntries();
    dataGeneration++;
    notifyListeners();
    return count;
  }

  /// Deletes all entries whose date falls in [start]..=[end] (inclusive).
  /// Returns rows deleted. Used by the calendar-based cleanup UI.
  Future<int> deleteDataInRange(DateTime start, DateTime end) async {
    final count = await _db.deleteEntriesInRange(
      _dateFmt.format(start),
      _dateFmt.format(end),
    );
    await _loadTodaysEntries();
    dataGeneration++;
    notifyListeners();
    return count;
  }

  /// Builds a CSV file (date,hour,category,note) of every entry ever
  /// logged, saves it to a temp file, and returns the file path so the
  /// caller can share/export it.
  Future<File> exportCsv() async {
    final today = _dateFmt.format(DateTime.now());
    final all = await _db.getEntriesForRange(_dateFmt.format(installDate), today);
    final buffer = StringBuffer('date,hour,category,note\n');
    for (final e in all) {
      final cat = categoryById(e.categoryId)?.name ?? '';
      final safeNote = e.note.replaceAll('"', '""');
      buffer.writeln('${e.date},${e.hour},"$cat","$safeNote"');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hour_tracker_export.csv');
    await file.writeAsString(buffer.toString());
    return file;
  }
}
