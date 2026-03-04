// RTLS Flutter Example — widget smoke tests.
// Uses semantics keys for stable, accessibility-friendly lookup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtls_flutter_example/main.dart';
import 'package:rtls_flutter_example/screens/home_screen.dart';

void main() {
  testWidgets('App launches and shows RTLS Demo', (WidgetTester tester) async {
    await tester.pumpWidget(const RTLSExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('RTLS Demo'), findsOneWidget);
  });

  testWidgets('Home screen has Apply Settings and semantic regions', (WidgetTester tester) async {
    await tester.pumpWidget(const RTLSExampleApp());
    await tester.pumpAndSettle();

    // Above-the-fold semantics (Status + Backend cards)
    expect(find.byKey(const Key(HomeScreenSemantics.applySettingsButton)), findsOneWidget);
    expect(find.byKey(const Key(HomeScreenSemantics.trackingStatus)), findsOneWidget);
    expect(find.byKey(const Key(HomeScreenSemantics.pendingQueueValue)), findsOneWidget);
  });
}
