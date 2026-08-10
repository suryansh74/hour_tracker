import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/root_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notifications quickly; never block forever on plugin setup.
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('NotificationService.init failed: $e\n$st');
  }
  NotificationService.instance.onBeepTapped = openLogSheetForHour;

  runApp(const HourTrackerApp());
}

class HourTrackerApp extends StatefulWidget {
  const HourTrackerApp({super.key});

  @override
  State<HourTrackerApp> createState() => _HourTrackerAppState();
}

class _HourTrackerAppState extends State<HourTrackerApp> with WidgetsBindingObserver {
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appState = AppState();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-schedule when user returns to the app (covers permission granted in Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && appState.initialized) {
      NotificationService.instance.scheduleDailyBeeps(
        wakeHour: appState.wakeHour,
        sleepHour: appState.sleepHour,
      );
    }
  }

  Future<void> _bootstrap() async {
    try {
      await appState.init();
    } catch (e, st) {
      debugPrint('AppState.init failed: $e\n$st');
      appState.forceInitialized();
    }

    try {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.scheduleDailyBeeps(
        wakeHour: appState.wakeHour,
        sleepHour: appState.sleepHour,
      );
    } catch (e, st) {
      debugPrint('Notification setup failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Hour Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: state.themeMode,
            home: state.initialized
                ? const RootScreen()
                : const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Starting Hour Tracker…'),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
