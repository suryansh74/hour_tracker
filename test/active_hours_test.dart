import 'package:flutter_test/flutter_test.dart';
import 'package:hour_tracker/utils/active_hours.dart';

void main() {
  group('activeHours', () {
    test('normal day window wake 6 sleep 23', () {
      final hours = activeHours(wakeHour: 6, sleepHour: 23);
      expect(hours.first, 6);
      expect(hours.last, 22);
      expect(hours.length, 17);
    });

    test('overnight window wake 22 sleep 6', () {
      final hours = activeHours(wakeHour: 22, sleepHour: 6);
      expect(hours, containsAll([22, 23, 0, 1, 2, 3, 4, 5]));
      expect(hours, isNot(contains(6)));
      expect(hours, isNot(contains(12)));
    });

    test('same wake and sleep yields empty', () {
      expect(activeHours(wakeHour: 8, sleepHour: 8), isEmpty);
    });
  });

  group('activeHourRangeLabels', () {
    test('labels are ranges not single hours', () {
      final labels = activeHourRangeLabels(wakeHour: 6, sleepHour: 9);
      expect(labels, ['06:00–07:00', '07:00–08:00', '08:00–09:00']);
    });
  });
}
