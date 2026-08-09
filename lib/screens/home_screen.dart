import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_state.dart';
import '../widgets/log_entry_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final now = DateTime.now();
    final hours = appState.activeHoursList;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(now)),
      ),
      body: FutureBuilder<int>(
        future: appState.currentStreak(),
        builder: (context, snapshot) {
          final streak = snapshot.data ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DisciplineScoreBanner(ratio: appState.todayDisciplineRatio),
              const SizedBox(height: 12),
              if (streak > 0) _StreakBanner(streak: streak),
              const SizedBox(height: 12),
              ...hours.map((hour) => _HourTile(hour: hour, isCurrentHour: hour == now.hour)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              '$streak day${streak == 1 ? '' : 's'} streak — keep it going',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisciplineScoreBanner extends StatelessWidget {
  final double ratio;
  const _DisciplineScoreBanner({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    final color = ratio >= 0.8 ? Colors.green : (ratio >= 0.5 ? Colors.orange : Colors.red);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: ratio, color: color, strokeWidth: 4, backgroundColor: color.withOpacity(0.15)),
                  Text('$pct', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "Today's discipline score — hours logged so far",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  final int hour;
  final bool isCurrentHour;
  const _HourTile({required this.hour, required this.isCurrentHour});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entry = appState.todaysEntries[hour];
    final category = appState.categoryById(entry?.categoryId);
    final now = DateTime.now();
    final isFuture = hour > now.hour;
    final isMissed = !isFuture && entry == null && hour != now.hour;

    final color = category != null ? Color(category.colorValue) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: !isFuture,
        onTap: isFuture ? null : () => showLogEntrySheet(context, hour),
        leading: CircleAvatar(
          backgroundColor: color?.withOpacity(0.2) ??
              (isMissed
                  ? Colors.red.withOpacity(0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest),
          child: Text(
            _hourLabel(hour),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? (isMissed ? Colors.red : null),
            ),
          ),
        ),
        title: Text(
          category?.name ?? (isFuture ? 'Upcoming' : (isMissed ? 'Not logged' : 'Tap to log')),
          style: TextStyle(
            color: isFuture ? Theme.of(context).disabledColor : null,
            fontWeight: entry != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: entry != null && entry.note.isNotEmpty ? Text(entry.note) : null,
        trailing: isCurrentHour
            ? const Icon(Icons.radio_button_checked, size: 14, color: Colors.green)
            : (entry != null ? const Icon(Icons.check_circle, color: Colors.green) : null),
      ),
    );
  }

  String _hourLabel(int hour) {
    final period = hour >= 12 ? 'P' : 'A';
    var h = hour % 12;
    if (h == 0) h = 12;
    return '$h$period';
  }
}
