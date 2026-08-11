import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hour_tracker/screens/about_screen.dart';

void main() {
  testWidgets('About screen shows core copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    expect(find.text('Why Hour Tracker?'), findsOneWidget);
    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('How to use it'), findsOneWidget);
  });
}
