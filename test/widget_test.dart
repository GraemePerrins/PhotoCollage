// This is a basic Flutter widget test for CollageStudio.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photocollage/main.dart';

void main() {
  testWidgets('App loads and displays main navigation items', (WidgetTester tester) async {
    // Set window size for desktop layout
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const CollageStudioApp());

    // Verify that the title is displayed.
    expect(find.text('Collage Studio'), findsOneWidget);

    // Verify navigation tabs.
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Image Library'), findsOneWidget);
  });
}
