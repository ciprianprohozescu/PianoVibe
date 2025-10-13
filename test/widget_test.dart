// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piano_vibe/app/main_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('MainApp renders tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
  });
}
