import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Active hours',
            child: Column(
              children: [
                _HourPickerRow(
                  label: 'Wake up',
                  hour: appState.wakeHour,
                  onChanged: (h) => appState.updateSleepWindow(newWake: h, newSleep: appState.sleepHour),
                ),
                const Divider(height: 24),
                _HourPickerRow(
                  label: 'Sleep',
                  hour: appState.sleepHour,
                  onChanged: (h) => appState.updateSleepWindow(newWake: appState.wakeHour, newSleep: h),
                ),
                const SizedBox(height: 8),
                Text(
                  'Beeps fire every hour between these times. No beeps during sleep.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Appearance',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
              ],
              selected: {appState.themeMode},
              onSelectionChanged: (s) => appState.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Categories',
            child: Column(
              children: [
                ...appState.categories.map((cat) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: Color(cat.colorValue), radius: 10),
                      title: Text(cat.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => appState.deleteCategory(cat.id!),
                      ),
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAddCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Notifications',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'If beeps stop arriving, re-check permissions (Android may disable exact alarms after updates).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => NotificationService.instance.requestPermissions(),
                  child: const Text('Re-check notification permissions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Data',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History is kept indefinitely by default — a year or more of data is fine and only helps long-term patterns. '
                  'If you ever want to trim very old data, you can do it manually below; nothing is deleted automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete data older than...'),
                  onPressed: () => _showDeleteOldDataDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    int selectedColor = kCategoryPalette.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('New category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: kCategoryPalette.map((c) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: CircleAvatar(
                          backgroundColor: Color(c),
                          radius: selectedColor == c ? 16 : 12,
                          child: selectedColor == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    context.read<AppState>().addCategory(controller.text.trim(), selectedColor);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteOldDataDialog(BuildContext context) {
    final options = <String, Duration>{
      'Older than 6 months': const Duration(days: 182),
      'Older than 1 year': const Duration(days: 365),
      'Older than 2 years': const Duration(days: 730),
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Delete old data'),
          children: options.entries.map((entry) {
            return SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final cutoff = DateTime.now().subtract(entry.value);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Are you sure?'),
                    content: Text(
                      'This permanently deletes all entries before ${cutoff.toLocal().toString().split(' ').first}. '
                      'This can\'t be undone.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  final count = await context.read<AppState>().deleteDataBefore(cutoff);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted $count old entries.')),
                    );
                  }
                }
              },
              child: Text(entry.key),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _HourPickerRow extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;
  const _HourPickerRow({required this.label, required this.hour, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: 0),
            );
            if (picked != null) onChanged(picked.hour);
          },
          child: Text(_formatHour(hour), style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    var h = hour % 12;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }
}
