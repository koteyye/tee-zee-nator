// This is a basic Flutter widget test for TeeZeeNator app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tee_zee_nator/main.dart';

void main() {
  testWidgets('TeeZeeNator app launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app shows either the setup screen or main screen
    // The app should show a loading indicator initially, then navigate
  final loading = find.byType(CircularProgressIndicator);
  final setup = find.text('Настройка подключения');
  final mainTitle = find.text('TeeZeeNator');
  // At least one of these should be present.
  expect(loading.evaluate().isNotEmpty || setup.evaluate().isNotEmpty || mainTitle.evaluate().isNotEmpty, isTrue);
  });
}
