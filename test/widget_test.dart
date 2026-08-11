import 'package:flutter_test/flutter_test.dart';
import 'package:hour_tracker/utils/active_hours.dart';

/// Smoke test kept for `flutter test` default entry.
void main() {
  test('active hours smoke', () {
    expect(activeHours(wakeHour: 6, sleepHour: 7), [6]);
  });
}
