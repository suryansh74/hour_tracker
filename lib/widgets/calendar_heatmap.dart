import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A compact, scrollable heatmap: one column per week, one cell per day,
/// shaded by how much of that day's active hours were logged. Good for
/// spotting long-term patterns (e.g. "my weekends are always empty") that
/// don't show up in a single week's bar chart.
class CalendarHeatmap extends StatelessWidget {
  final Map<String, int> countByDate; // 'yyyy-MM-dd' -> hours logged
  final int expectedPerDay;
  final DateTime installDate;
  final int daysToShow;

  const CalendarHeatmap({
    super.key,
    required this.countByDate,
    required this.expectedPerDay,
    required this.installDate,
    this.daysToShow = 180,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    final start = today.subtract(Duration(days: daysToShow - 1));
    // Align to the previous Sunday so weeks stack into clean columns.
    final alignedStart = start.subtract(Duration(days: start.weekday % 7));

    final totalDays = today.difference(alignedStart).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(weeks, (weekIndex) {
          return Column(
            children: List.generate(7, (dayIndex) {
              final day = alignedStart.add(Duration(days: weekIndex * 7 + dayIndex));
              final isFuture = day.isAfter(today);
              final beforeInstall = day.isBefore(DateTime(installDate.year, installDate.month, installDate.day));
              final key = dateFmt.format(day);
              final count = countByDate[key] ?? 0;
              final ratio = expectedPerDay == 0 ? 0.0 : count / expectedPerDay;

              return Padding(
                padding: const EdgeInsets.all(1.5),
                child: Tooltip(
                  message: isFuture || beforeInstall ? '' : '${DateFormat('MMM d').format(day)}: $count/$expectedPerDay logged',
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isFuture || beforeInstall ? Colors.transparent : _colorForRatio(context, ratio),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Color _colorForRatio(BuildContext context, double ratio) {
    final base = Theme.of(context).colorScheme.primary;
    if (ratio <= 0) return Theme.of(context).colorScheme.surfaceContainerHighest;
    if (ratio < 0.3) return base.withOpacity(0.25);
    if (ratio < 0.6) return base.withOpacity(0.5);
    if (ratio < 0.85) return base.withOpacity(0.75);
    return base;
  }
}
