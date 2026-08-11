import 'package:flutter/material.dart';

/// Simple in-app guidelines: why the app exists and how to use it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Why Hour Tracker?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Most of the day disappears into half-remembered blocks. '
            'Hour Tracker is a lightweight, offline habit: once an hour it asks '
            'what you were doing, so you can see where time actually went — '
            'not where you meant it to go.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text('How to use it', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _bullet(theme, 'Set wake and sleep times in Settings so beeps only run while you are up.'),
          _bullet(theme, 'When a beep arrives, pick a category and optionally add a short note.'),
          _bullet(theme, 'Check Today for the current day; History for past days (read-only).'),
          _bullet(theme, 'Dashboard shows patterns: categories, heatmap, and a quiet discipline score.'),
          _bullet(theme, 'Everything stays on your phone. No account, no cloud.'),
          const SizedBox(height: 24),
          Text('Notifications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Allow notifications and “Alarms & reminders” on Android, and avoid aggressive '
            'battery optimization for this app, so hourly check-ins can fire on time.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Privacy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Logs are stored only in a local database on your device. '
            'You can export CSV or delete a date range anytime from Settings.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'Hour Tracker — offline hourly awareness.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: theme.textTheme.bodyMedium),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
