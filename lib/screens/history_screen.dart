import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/hour_entry.dart';
import '../providers/app_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<String>>(
        key: ValueKey('history-${appState.dataGeneration}'),
        future: appState.historyDateKeys(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dateKeys = snapshot.data!;
          if (dateKeys.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No past days yet — history starts showing up once today\nbecomes yesterday.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Group by "MMMM yyyy" for month headers.
          final monthFmt = DateFormat('MMMM yyyy');
          final grouped = <String, List<String>>{};
          for (final key in dateKeys) {
            final date = DateFormat('yyyy-MM-dd').parse(key);
            grouped.putIfAbsent(monthFmt.format(date), () => []).add(key);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.expand((monthGroup) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    monthGroup.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...monthGroup.value.map((key) => _DayRow(dateKey: key)),
              ];
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String dateKey;
  const _DayRow({required this.dateKey});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final expected = appState.activeHoursList.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(DateFormat('EEEE, MMM d').format(date)),
        trailing: FutureBuilder<List<HourEntry>>(
          future: appState.entriesForHistoryDate(dateKey),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            final ratio = expected == 0 ? 0.0 : count / expected;
            return Text(
              '$count / $expected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ratio >= 0.8
                    ? Colors.green
                    : ratio >= 0.5
                        ? Colors.orange
                        : Colors.red,
              ),
            );
          },
        ),
        onTap: () => _showDayDetail(context, dateKey, date),
      ),
    );
  }

  void _showDayDetail(BuildContext context, String dateKey, DateTime date) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return FutureBuilder<List<HourEntry>>(
              future: appState.entriesForHistoryDate(dateKey),
              builder: (ctx, snapshot) {
                final entries = (snapshot.data ?? [])..sort((a, b) => a.hour.compareTo(b.hour));
                final byHour = {for (final e in entries) e.hour: e};

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(date),
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Read-only — past days can\'t be edited.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: appState.activeHoursList.map((hour) {
                            final entry = byHour[hour];
                            final cat = appState.categoryById(entry?.categoryId);
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: cat != null
                                    ? Color(cat.colorValue).withOpacity(0.2)
                                    : Colors.red.withOpacity(0.1),
                                child: Text(
                                  '$hour',
                                  style: TextStyle(fontSize: 11, color: cat != null ? Color(cat.colorValue) : Colors.red),
                                ),
                              ),
                              title: Text(cat?.name ?? 'Not logged'),
                              subtitle: entry != null && entry.note.isNotEmpty ? Text(entry.note) : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
