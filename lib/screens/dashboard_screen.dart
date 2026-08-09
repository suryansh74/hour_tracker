import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/hour_entry.dart';
import '../providers/app_state.dart';
import '../widgets/calendar_heatmap.dart';

enum _Range { week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Range range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final days = range == _Range.week ? 7 : 30;
    final dateFmt = DateFormat('yyyy-MM-dd');
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () async {
              final file = await appState.exportCsv();
              await Share.shareXFiles([XFile(file.path)], text: 'Hour Tracker export');
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<_Range>(
              segments: const [
                ButtonSegment(value: _Range.week, label: Text('Week')),
                ButtonSegment(value: _Range.month, label: Text('Month')),
              ],
              selected: {range},
              onSelectionChanged: (s) => setState(() => range = s.first),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<HourEntry>>>(
        future: appState.entriesGroupedByDate(dateFmt.format(start), dateFmt.format(end)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final grouped = snapshot.data!;
          final allEntries = grouped.values.expand((e) => e).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ScoreCard(appState: appState),
              const SizedBox(height: 20),
              _SectionTitle('Last 6 months'),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, List<HourEntry>>>(
                future: appState.entriesGroupedByDate(
                  dateFmt.format(DateTime.now().subtract(const Duration(days: 179))),
                  dateFmt.format(end),
                ),
                builder: (context, heatSnapshot) {
                  if (!heatSnapshot.hasData) {
                    return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
                  }
                  final countByDate = {
                    for (final e in heatSnapshot.data!.entries) e.key: e.value.length,
                  };
                  return CalendarHeatmap(
                    countByDate: countByDate,
                    expectedPerDay: appState.activeHoursList.length,
                    installDate: appState.installDate,
                  );
                },
              ),
              const SizedBox(height: 28),
              _SectionTitle('Time by category'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _CategoryPieChart(entries: allEntries, appState: appState),
              ),
              const SizedBox(height: 28),
              _SectionTitle('Hours logged per day'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _DailyBarChart(
                  grouped: grouped,
                  start: start,
                  days: days,
                  expectedPerDay: appState.activeHoursList.length,
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle('Daily log'),
              const SizedBox(height: 12),
              _DailyTable(grouped: grouped, start: start, days: days, appState: appState),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final AppState appState;
  const _ScoreCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([appState.disciplineScore(), appState.lifetimeMissedHours()]),
      builder: (context, snapshot) {
        final score = snapshot.data?[0] ?? 70;
        final missed = snapshot.data?[1] ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discipline score', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('$score', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('based on the last 60 days', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(width: 1, height: 44, color: Theme.of(context).dividerColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lifetime missed hours', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('$missed', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('never resets — data, not guilt', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
}

class _CategoryPieChart extends StatelessWidget {
  final List<HourEntry> entries;
  final AppState appState;
  const _CategoryPieChart({required this.entries, required this.appState});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data yet — start logging your hours.'));
    }
    final counts = <int, int>{};
    for (final e in entries) {
      if (e.categoryId == null) continue;
      counts[e.categoryId!] = (counts[e.categoryId!] ?? 0) + 1;
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: counts.entries.map((e) {
                final cat = appState.categoryById(e.key);
                final pct = total == 0 ? 0 : (e.value / total * 100);
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: cat != null ? Color(cat.colorValue) : Colors.grey,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: counts.entries.map((e) {
              final cat = appState.categoryById(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: cat != null ? Color(cat.colorValue) : Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(cat?.name ?? 'Unknown', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    Text('${e.value}h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final Map<String, List<HourEntry>> grouped;
  final DateTime start;
  final int days;
  final int expectedPerDay;
  const _DailyBarChart({
    required this.grouped,
    required this.start,
    required this.days,
    required this.expectedPerDay,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final labelFmt = DateFormat('E');
    final step = days > 14 ? (days / 10).ceil() : 1;

    return BarChart(
      BarChartData(
        maxY: (expectedPerDay + 2).toDouble(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days || idx % step != 0) return const SizedBox.shrink();
                final day = start.add(Duration(days: idx));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labelFmt.format(day), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(days, (i) {
          final day = start.add(Duration(days: i));
          final key = dateFmt.format(day);
          final count = grouped[key]?.length ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: days > 14 ? 6 : 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DailyTable extends StatelessWidget {
  final Map<String, List<HourEntry>> grouped;
  final DateTime start;
  final int days;
  final AppState appState;
  const _DailyTable({required this.grouped, required this.start, required this.days, required this.appState});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final labelFmt = DateFormat('EEE, MMM d');
    final expected = appState.activeHoursList.length;

    final rows = List.generate(days, (i) => start.add(Duration(days: days - 1 - i)))
        .where((d) => !d.isAfter(DateTime.now()))
        .toList();

    return Card(
      child: Column(
        children: rows.map((day) {
          final key = dateFmt.format(day);
          final count = grouped[key]?.length ?? 0;
          final ratio = expected == 0 ? 0.0 : count / expected;
          return ListTile(
            dense: true,
            title: Text(labelFmt.format(day)),
            trailing: Text(
              '$count / $expected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ratio >= 0.8
                    ? Colors.green
                    : ratio >= 0.5
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
