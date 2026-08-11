import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules "log your activity" reminders inside the user's active window
/// at a configurable interval (minutes).
///
/// Strategy: rolling one-shot alarms (same approach that worked for minute tests),
/// refilled on app open / settings change. More reliable on OEM Android than
/// long-lived daily `matchDateTimeComponents` schedules.
///
/// Notification ids:
/// - 2000–2299 → interval beeps (rolling window)
/// - 999 → immediate test
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'hourly_beep_v4';
  static const _channelName = 'Hourly Check-in';

  static const int _intervalIdStart = 2000;
  static const int _intervalIdEnd = 2299;

  /// Max one-shots to keep pending (Android has limits; 48 is safe).
  static const int maxPendingBeeps = 48;

  void Function(int hour)? onBeepTapped;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('minute:') || payload.startsWith('interval:')) {
          // Optional: could open log sheet for current hour
          final hour = DateTime.now().hour;
          onBeepTapped?.call(hour);
          return;
        }
        final hour = int.tryParse(payload);
        if (hour != null) onBeepTapped?.call(hour);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminds you to log what you did during the active window.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('requestNotificationsPermission: $e');
    }
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('requestExactAlarmsPermission: $e');
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('iOS requestPermissions: $e');
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminds you to log what you did during the active window.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
      );

  Future<void> showTestNotification() async {
    await _plugin.show(
      999,
      'Hour Tracker test',
      'If you hear this, notifications + sound work.',
      _details,
    );
  }

  // ---------------------------------------------------------------------------
  // Custom interval scheduling (main feature)
  // ---------------------------------------------------------------------------

  /// Schedule beeps every [intervalMinutes] between [wakeHour] and [sleepHour].
  /// Uses rolling one-shots (works on the same path as the successful minute tests).
  Future<int> scheduleBeeps({
    required int wakeHour,
    required int sleepHour,
    required int intervalMinutes,
  }) async {
    final interval = intervalMinutes.clamp(1, 24 * 60);
    await _cancelIntervalBeeps();

    final times = _nextBeepTimes(
      wakeHour: wakeHour,
      sleepHour: sleepHour,
      intervalMinutes: interval,
      count: maxPendingBeeps,
    );

    final exactOk = await canScheduleExactAlarms();
    var mode = exactOk ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint(
      'scheduleBeeps: interval=${interval}m wake=$wakeHour sleep=$sleepHour '
      'times=${times.length} exactOk=$exactOk mode=$mode',
    );

    var scheduled = 0;
    for (var i = 0; i < times.length; i++) {
      final when = times[i];
      final id = _intervalIdStart + i;
      final label = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
      final ok = await _zonedOneShot(
        id: id,
        title: 'Log your activity',
        body: 'Check-in time ($label). What were you doing?',
        when: when,
        mode: mode,
        payload: 'interval:${when.hour}:${when.minute}',
      );
      if (ok) {
        scheduled++;
      } else if (mode == AndroidScheduleMode.alarmClock) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
        if (await _zonedOneShot(
          id: id,
          title: 'Log your activity',
          body: 'Check-in time ($label). What were you doing?',
          when: when,
          mode: mode,
          payload: 'interval:${when.hour}:${when.minute}',
        )) {
          scheduled++;
        }
      }
    }
    debugPrint('scheduleBeeps done: $scheduled / ${times.length}');
    return scheduled;
  }

  /// Back-compat name used by older call sites.
  Future<void> scheduleDailyBeeps({
    required int wakeHour,
    required int sleepHour,
    int intervalMinutes = 60,
  }) async {
    await scheduleBeeps(
      wakeHour: wakeHour,
      sleepHour: sleepHour,
      intervalMinutes: intervalMinutes,
    );
  }

  Future<bool> _zonedOneShot({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required AndroidScheduleMode mode,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('zonedOneShot id=$id failed: $e');
      return false;
    }
  }

  Future<void> _cancelIntervalBeeps() async {
    for (var id = _intervalIdStart; id <= _intervalIdEnd; id++) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    // Also clear legacy hourly ids 0-23 from older builds.
    for (var h = 0; h < 24; h++) {
      try {
        await _plugin.cancel(h);
      } catch (_) {}
    }
  }

  /// Build the next [count] fire times aligned to the interval grid,
  /// only inside the active wake→sleep window (supports overnight windows).
  List<tz.TZDateTime> _nextBeepTimes({
    required int wakeHour,
    required int sleepHour,
    required int intervalMinutes,
    required int count,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    // Align to next interval boundary from local midnight-based grid.
    final startOfDay = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    var cursor = startOfDay;
    // Fast-forward to first boundary strictly after now.
    while (!cursor.isAfter(now)) {
      cursor = cursor.add(Duration(minutes: intervalMinutes));
    }

    final result = <tz.TZDateTime>[];
    // Search up to ~3 days ahead so overnight windows still fill.
    final limit = now.add(const Duration(days: 3));
    // Short intervals (1/5/15/30) are for testing scheduled alarms on release
    // builds — fire regardless of wake/sleep. Hourly (60+) still respects the window.
    final respectWindow = intervalMinutes >= 60;
    while (result.length < count && cursor.isBefore(limit)) {
      if (!respectWindow || _isInActiveWindow(cursor, wakeHour, sleepHour)) {
        result.add(cursor);
      }
      cursor = cursor.add(Duration(minutes: intervalMinutes));
    }
    return result;
  }

  bool _isInActiveWindow(tz.TZDateTime t, int wakeHour, int sleepHour) {
    final minutes = t.hour * 60 + t.minute;
    final wake = wakeHour * 60;
    final sleep = sleepHour * 60;
    if (wake < sleep) {
      // e.g. 06:00–23:00 → active if wake <= t < sleep
      return minutes >= wake && minutes < sleep;
    }
    // Overnight, e.g. wake 22 sleep 6 → active if t >= 22:00 OR t < 06:00
    return minutes >= wake || minutes < sleep;
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
