import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/root_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();
  NotificationService.instance.onBeepTapped = openLogSheetForHour;

  runApp(const HourTrackerApp());
}

class HourTrackerApp extends StatefulWidget {
  const HourTrackerApp({super.key});

  @override
  State<HourTrackerApp> createState() => _HourTrackerAppState();
}

class _HourTrackerAppState extends State<HourTrackerApp> {
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    appState = AppState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await appState.init();
    // Ask for notification permissions right after first load, so the
    // very first day of use already gets beeps.
    await NotificationService.instance.requestPermissions();
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
                : const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        },
      ),
    );
  }
}
