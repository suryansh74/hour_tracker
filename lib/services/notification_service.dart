import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules hourly "log your activity" reminders inside the active window.
///
/// Rolling one-shot alarms, refilled on app open / wake-sleep change.
///
/// Notification ids:
/// - 2000–2299 → hourly beeps
/// - 999 → immediate test
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Bump channel id when sound/importance must change (Android freezes channels).
  static const _channelId = 'hourly_beep_v4';
  static const _channelName = 'Hourly Check-in';

  static const int _intervalIdStart = 2000;
  static const int _intervalIdEnd = 2299;
  static const int maxPendingBeeps = 48;

  void Function(int hour)? onBeepTapped;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    // White silhouette for the status bar (safe). Avoid adaptive mipmap XML here.
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_hour_tracker');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('interval:') || payload.startsWith('minute:')) {
          onBeepTapped?.call(DateTime.now().hour);
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
  }

  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Notification details without largeIcon.
  /// Adaptive launcher XML (`ic_launcher`) is not a bitmap and can make show() throw
  /// on many devices — which is why the test button stopped showing a snackbar.
  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminds you to log what you did during the active window.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: 'ic_stat_hour_tracker',
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
      );

  /// Returns true if the OS accepted the notification.
  Future<bool> showTestNotification() async {
    try {
      await _plugin.show(
        999,
        'Hour Tracker test',
        'If you hear this, notifications + sound work.',
        _details,
      );
      return true;
    } catch (e, st) {
      debugPrint('showTestNotification failed: $e\n$st');
      return false;
    }
  }

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
      final label =
          '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
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
    for (var h = 0; h < 24; h++) {
      try {
        await _plugin.cancel(h);
      } catch (_) {}
    }
  }

  List<tz.TZDateTime> _nextBeepTimes({
    required int wakeHour,
    required int sleepHour,
    required int intervalMinutes,
    required int count,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    final startOfDay = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    var cursor = startOfDay;
    while (!cursor.isAfter(now)) {
      cursor = cursor.add(Duration(minutes: intervalMinutes));
    }

    final result = <tz.TZDateTime>[];
    final limit = now.add(const Duration(days: 3));
    while (result.length < count && cursor.isBefore(limit)) {
      if (_isInActiveWindow(cursor, wakeHour, sleepHour)) {
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
      return minutes >= wake && minutes < sleep;
    }
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
