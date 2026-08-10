import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Handles scheduling of the recurring hourly "log your hour" notifications,
/// skipping the user's configured sleep window.
///
/// Notification ids:
/// - 0–23  → daily hourly beeps
/// - 1001–1099 → debug per-minute test beeps (one-shots)
/// - 999 → immediate test beep
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Bump when channel sound/importance must change — Android freezes
  /// channel settings after first create.
  static const _channelId = 'hourly_beep_v3';
  static const _channelName = 'Hourly Check-in';

  static const int _minuteTestIdStart = 1001;
  static const int _minuteTestIdEnd = 1099;

  /// Called when a notification is tapped.
  void Function(int hour)? onBeepTapped;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    _setLocalTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        // Minute-test payloads look like "minute:3"
        if (payload.startsWith('minute:')) return;
        final hour = int.tryParse(payload);
        if (hour != null) onBeepTapped?.call(hour);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminds you every active hour to log what you did.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Best-effort local TZ. Prefer Asia/Kolkata for this app's primary users;
  /// if device offset differs a lot, still use Kolkata wall-clock which matches
  /// India phones. (Custom TZ can come later with custom intervals.)
  void _setLocalTimezone() {
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      final now = tz.TZDateTime.now(tz.local);
      debugPrint('Notification TZ=Asia/Kolkata now=$now deviceOffset=${DateTime.now().timeZoneOffset}');
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
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
          channelDescription: 'Reminds you every active hour to log what you did.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
      );

  /// Immediate test — confirms channel + permission + sound work.
  Future<void> showTestNotification() async {
    await _plugin.show(
      999,
      'Hour Tracker test',
      'If you hear this, notifications + sound work.',
      _details,
    );
  }

  /// DEBUG: schedule one-shot beeps for the next [count] minutes (not recurring).
  /// Use this to verify zonedSchedule + exact alarms without waiting an hour.
  ///
  /// Returns how many were successfully scheduled.
  Future<int> scheduleMinuteTestBeeps({int count = 5}) async {
    await cancelMinuteTestBeeps();

    final exactOk = await canScheduleExactAlarms();
    // alarmClock is the most reliable on modern Android for precise wakeups.
    final mode = exactOk
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;
    final max = count.clamp(1, _minuteTestIdEnd - _minuteTestIdStart + 1);

    for (var i = 1; i <= max; i++) {
      final when = now.add(Duration(minutes: i));
      final id = _minuteTestIdStart + i - 1;
      try {
        await _plugin.zonedSchedule(
          id,
          'Minute test #$i',
          'Scheduled for ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')} (debug)',
          when,
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          // NO matchDateTimeComponents → pure one-shot (good for testing)
          payload: 'minute:$i',
        );
        scheduled++;
        debugPrint('Minute test #$i id=$id at $when mode=$mode');
      } catch (e) {
        debugPrint('Minute test #$i failed: $e');
        // Retry with softer mode once
        if (mode == AndroidScheduleMode.alarmClock) {
          try {
            await _plugin.zonedSchedule(
              id,
              'Minute test #$i',
              'Scheduled for ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')} (debug)',
              when,
              _details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'minute:$i',
            );
            scheduled++;
          } catch (e2) {
            debugPrint('Minute test #$i exact fallback failed: $e2');
          }
        }
      }
    }
    debugPrint('Minute tests scheduled: $scheduled / $max (exactOk=$exactOk)');
    return scheduled;
  }

  Future<void> cancelMinuteTestBeeps() async {
    for (var id = _minuteTestIdStart; id <= _minuteTestIdEnd; id++) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Daily hourly beeps between [wakeHour] (inclusive) and [sleepHour] (exclusive).
  Future<void> scheduleDailyBeeps({required int wakeHour, required int sleepHour}) async {
    // Cancel only hourly ids (0-23), keep minute-test ids if any.
    for (var h = 0; h < 24; h++) {
      try {
        await _plugin.cancel(h);
      } catch (_) {}
    }

    final activeHours = <int>[];
    if (wakeHour < sleepHour) {
      activeHours.addAll([for (var h = wakeHour; h < sleepHour; h++) h]);
    } else {
      activeHours.addAll([for (var h = wakeHour; h < 24; h++) h]);
      activeHours.addAll([for (var h = 0; h < sleepHour; h++) h]);
    }

    final exactOk = await canScheduleExactAlarms();
    // Prefer alarmClock for reliability when exact is allowed.
    var mode = exactOk
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint(
      'Hourly schedule: ${activeHours.length} hours, exactOk=$exactOk mode=$mode '
      'wake=$wakeHour sleep=$sleepHour tz=${tz.local.name}',
    );

    var scheduled = 0;
    for (final hour in activeHours) {
      final when = _nextInstanceOfHour(hour);
      final ok = await _scheduleOneHourly(
        id: hour,
        hour: hour,
        when: when,
        mode: mode,
      );
      if (ok) {
        scheduled++;
      } else if (mode == AndroidScheduleMode.alarmClock) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
        if (await _scheduleOneHourly(id: hour, hour: hour, when: when, mode: mode)) {
          scheduled++;
        } else {
          mode = AndroidScheduleMode.inexactAllowWhileIdle;
          if (await _scheduleOneHourly(id: hour, hour: hour, when: when, mode: mode)) {
            scheduled++;
          }
        }
      }
    }
    debugPrint('Hourly scheduled: $scheduled / ${activeHours.length}');
  }

  Future<bool> _scheduleOneHourly({
    required int id,
    required int hour,
    required tz.TZDateTime when,
    required AndroidScheduleMode mode,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        'Log your last hour',
        'What were you doing? Tap to record it.',
        when,
        _details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: hour.toString(),
      );
      debugPrint('Hourly id=$id at $when mode=$mode OK');
      return true;
    } catch (e) {
      debugPrint('Hourly id=$id mode=$mode failed: $e');
      return false;
    }
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Pending notifications (for debug UI).
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
