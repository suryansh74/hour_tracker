import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Handles scheduling of the recurring hourly "log your hour" notifications,
/// skipping the user's configured sleep window.
///
/// Notification ids 0-23 are reserved, one per hour of day, so re-scheduling
/// is just: cancel all, then schedule the active-hour subset again.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Bump this if channel sound/importance must change — Android freezes
  /// channel settings after first create.
  static const _channelId = 'hourly_beep_v2';
  static const _channelName = 'Hourly Check-in';

  /// Called when a notification is tapped. Set from main() so the UI layer
  /// can navigate to the correct hour's log sheet. Receives the tapped hour.
  void Function(int hour)? onBeepTapped;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      // Device-local wall clock for India-default installs; safe fallback UTC.
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
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final hour = int.tryParse(response.payload ?? '');
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

  /// Immediate test notification so the user can verify sound + permission.
  Future<void> showTestNotification() async {
    const details = NotificationDetails(
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
    await _plugin.show(
      999,
      'Hour Tracker test',
      'If you hear this, notifications are working.',
      details,
    );
  }

  /// Reschedules all daily beeps to fire once per hour between [wakeHour]
  /// (inclusive) and [sleepHour] (exclusive) every day, indefinitely.
  Future<void> scheduleDailyBeeps({required int wakeHour, required int sleepHour}) async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll: $e');
    }

    final activeHours = <int>[];
    if (wakeHour < sleepHour) {
      activeHours.addAll([for (var h = wakeHour; h < sleepHour; h++) h]);
    } else {
      activeHours.addAll([for (var h = wakeHour; h < 24; h++) h]);
      activeHours.addAll([for (var h = 0; h < sleepHour; h++) h]);
    }

    final exactOk = await canScheduleExactAlarms();
    var mode = exactOk ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    debugPrint('Scheduling ${activeHours.length} beeps; exact=$exactOk mode=$mode wake=$wakeHour sleep=$sleepHour');

    var scheduled = 0;
    for (final hour in activeHours) {
      final when = _nextInstanceOfHour(hour);
      try {
        await _plugin.zonedSchedule(
          hour,
          'Log your last hour',
          'What were you doing? Tap to record it.',
          when,
          const NotificationDetails(
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
          ),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: hour.toString(),
        );
        scheduled++;
      } catch (e) {
        debugPrint('zonedSchedule hour=$hour mode=$mode failed: $e');
        if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
          mode = AndroidScheduleMode.inexactAllowWhileIdle;
          try {
            await _plugin.zonedSchedule(
              hour,
              'Log your last hour',
              'What were you doing? Tap to record it.',
              when,
              const NotificationDetails(
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
              ),
              androidScheduleMode: mode,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: hour.toString(),
            );
            scheduled++;
          } catch (e2) {
            debugPrint('zonedSchedule fallback hour=$hour failed: $e2');
          }
        }
      }
    }
    debugPrint('Scheduled $scheduled / ${activeHours.length} hourly notifications');
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
