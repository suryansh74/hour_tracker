/// Pure helpers for wake/sleep windows (easy to unit-test).
library;

/// Hours [wake, sleep) when wake < sleep; overnight when wake > sleep.
List<int> activeHours({required int wakeHour, required int sleepHour}) {
  if (wakeHour == sleepHour) return [];
  if (wakeHour < sleepHour) {
    return [for (var h = wakeHour; h < sleepHour; h++) h];
  }
  return [
    for (var h = wakeHour; h < 24; h++) h,
    for (var h = 0; h < sleepHour; h++) h,
  ];
}

/// Interval labels like "6:00–7:00" for each active start hour.
List<String> activeHourRangeLabels({required int wakeHour, required int sleepHour}) {
  return activeHours(wakeHour: wakeHour, sleepHour: sleepHour)
      .map((h) => '${_fmt(h)}–${_fmt((h + 1) % 24)}')
      .toList();
}

String _fmt(int hour) {
  final h = hour % 24;
  return '${h.toString().padLeft(2, '0')}:00';
}
