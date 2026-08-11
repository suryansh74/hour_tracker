import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                  'Hourly beeps fire between these times. No beeps during sleep.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Beep interval (release test)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how often the scheduled bell rings. '
                  'Use 1 or 5 min to test a GitHub-release install without waiting an hour. '
                  'Short intervals ignore wake/sleep so they fire anytime; 1 hour still uses your active hours.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in [1, 5, 15, 30, 60])
                      ChoiceChip(
                        label: Text(
                          minutes < 60 ? '$minutes min' : '1 hour',
                        ),
                        selected: appState.beepIntervalMinutes == minutes,
                        onSelected: (_) async {
                          await appState.updateBeepInterval(minutes);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Scheduled: ${appState.beepIntervalLabel}. '
                                  'Leave the app and wait to verify release builds.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected: ${appState.beepIntervalLabel}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Delete "${cat.name}"?'),
                              content: const Text(
                                'This also permanently removes every hour that was logged under this category. '
                                'Those slots will become empty again (not shown as "Unknown").',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            await appState.deleteCategory(cat.id!);
                          }
                        },
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
                  'Beeps once per hour between your wake and sleep times. '
                  'On many phones, allow notifications and "Alarms & reminders", '
                  'and turn off battery optimization for this app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Send test notification now'),
                  onPressed: () async {
                    await NotificationService.instance.requestPermissions();
                    await NotificationService.instance.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification sent — check sound/banner')),
                      );
                    }
                  },
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
                  'History is kept indefinitely by default. '
                  'You can permanently delete a date range between the day you started '
                  'using the app and yesterday.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete data by date range…'),
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    Text('Colour', style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...kCategoryPalette.map((c) {
                          final selected = selectedColor == c;
                          return GestureDetector(
                            onTap: () => setState(() => selectedColor = c),
                            child: CircleAvatar(
                              backgroundColor: Color(c),
                              radius: selected ? 16 : 13,
                              child: selected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                        // Custom colour entry point
                        GestureDetector(
                          onTap: () async {
                            final custom = await _showCustomColorPicker(ctx, Color(selectedColor));
                            if (custom != null) {
                              // Color.value is the ARGB int used by TrackCategory.
                              // ignore: deprecated_member_use
                              setState(() => selectedColor = custom.value);
                            }
                          },
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.palette_outlined,
                              size: 16,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Color(selectedColor), radius: 10),
                        const SizedBox(width: 8),
                        Text(
                          'Selected',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
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

  /// Simple HSV colour picker — no extra package needed.
  Future<Color?> _showCustomColorPicker(BuildContext context, Color initial) {
    var hue = HSVColor.fromColor(initial).hue;
    var saturation = HSVColor.fromColor(initial).saturation.clamp(0.2, 1.0);
    var value = HSVColor.fromColor(initial).value.clamp(0.3, 1.0);

    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final current = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
            return AlertDialog(
              title: const Text('Custom colour'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: current,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Hue', style: Theme.of(ctx).textTheme.labelMedium),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) => setState(() => hue = v),
                  ),
                  Text('Saturation', style: Theme.of(ctx).textTheme.labelMedium),
                  Slider(
                    value: saturation,
                    min: 0.15,
                    max: 1,
                    onChanged: (v) => setState(() => saturation = v),
                  ),
                  Text('Brightness', style: Theme.of(ctx).textTheme.labelMedium),
                  Slider(
                    value: value,
                    min: 0.25,
                    max: 1,
                    onChanged: (v) => setState(() => value = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, current),
                  child: const Text('Use colour'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteOldDataDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    final today = DateTime.now();
    // Deletion window is only between the day the user started using the app
    // and yesterday (today is still editable / in progress).
    final firstDate = DateTime(appState.installDate.year, appState.installDate.month, appState.installDate.day);
    final lastDate = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

    if (lastDate.isBefore(firstDate)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No past data to delete yet.')),
        );
      }
      return;
    }

    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: firstDate, end: lastDate),
      helpText: 'Select range to delete',
      saveText: 'Continue',
    );

    if (range == null || !context.mounted) return;

    final fmt = DateFormat('yyyy-MM-dd');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(
          'This permanently deletes every logged hour from '
          '${fmt.format(range.start)} through ${fmt.format(range.end)} inclusive. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final count = await appState.deleteDataInRange(range.start, range.end);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count entries.')),
        );
      }
    }
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
