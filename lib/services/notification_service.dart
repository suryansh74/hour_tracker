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

  /// Called when a notification is tapped. Set from main() so the UI layer
  /// can navigate to the correct hour's log sheet. Receives the tapped hour.
  void Function(int hour)? onBeepTapped;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
      'hourly_beep',
      'Hourly Check-in',
      description: 'Reminds you every active hour to log what you did.',
      importance: Importance.max,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Reschedules all daily beeps to fire once per hour between [wakeHour]
  /// (inclusive) and [sleepHour] (exclusive) every day, indefinitely.
  Future<void> scheduleDailyBeeps({required int wakeHour, required int sleepHour}) async {
    await _plugin.cancelAll();

    final activeHours = <int>[];
    if (wakeHour < sleepHour) {
      activeHours.addAll([for (var h = wakeHour; h < sleepHour; h++) h]);
    } else {
      // Sleep window wraps past midnight (e.g. wake 6, sleep 1am next day).
      activeHours.addAll([for (var h = wakeHour; h < 24; h++) h]);
      activeHours.addAll([for (var h = 0; h < sleepHour; h++) h]);
    }

    for (final hour in activeHours) {
      await _plugin.zonedSchedule(
        hour,
        'Log your last hour',
        'What were you doing? Tap to record it.',
        _nextInstanceOfHour(hour),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hourly_beep',
            'Hourly Check-in',
            channelDescription: 'Reminds you every active hour to log what you did.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: hour.toString(),
      );
    }
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
