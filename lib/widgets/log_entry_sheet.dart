import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/app_state.dart';

Future<void> showLogEntrySheet(BuildContext context, int hour) async {
  final appState = context.read<AppState>();
  final existing = appState.todaysEntries[hour];
  int? selectedCategoryId = existing?.categoryId ?? appState.categories.firstOrNull?.id;
  final noteController = TextEditingController(text: existing?.note ?? '');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What did you do at ${_formatHour(hour)}?',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: appState.categories.map((cat) {
                    final selected = cat.id == selectedCategoryId;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: selected,
                      selectedColor: Color(cat.colorValue).withOpacity(0.25),
                      side: BorderSide(color: Color(cat.colorValue)),
                      avatar: CircleAvatar(backgroundColor: Color(cat.colorValue), radius: 6),
                      onSelected: (_) => setSheetState(() => selectedCategoryId = cat.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Fixed the notification bug',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () {
                          appState.deleteHourEntry(hour);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: selectedCategoryId == null
                          ? null
                          : () {
                              appState.logHour(
                                hour: hour,
                                categoryId: selectedCategoryId!,
                                note: noteController.text.trim(),
                              );
                              Navigator.pop(ctx);
                            },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _formatHour(int hour) {
  final period = hour >= 12 ? 'PM' : 'AM';
  var h = hour % 12;
  if (h == 0) h = 12;
  return '$h:00 $period';
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
