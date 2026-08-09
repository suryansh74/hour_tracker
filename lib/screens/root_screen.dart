import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/log_entry_sheet.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Global key so the notification tap handler (set up in main.dart) can
/// push a dialog/sheet on top of whatever screen is currently showing.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const _screens = [HomeScreen(), DashboardScreen(), HistoryScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    // Keep the notification-tap handler pointed at a valid context.
    context.read<AppState>();

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Called from main.dart's NotificationService.onBeepTapped callback.
void openLogSheetForHour(int hour) {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null) {
    showLogEntrySheet(ctx, hour);
  }
}
