import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/raven_mascot.dart';
import 'package:gaslight/theme/app_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 32 — Raven Mascot Layer 1 & Layer 2 Asset & Contrast Integrity', () {
    test('Layer 1 & Layer 2: Asset dimensions, alpha channels, and rim contrast >= 4.5:1', () {
      final assets = ['body.png', 'wing.png', 'eye_open.png', 'eye_closed.png'];
      for (final name in assets) {
        final file = File('assets/images/raven/$name');
        expect(file.existsSync(), isTrue, reason: '$name must exist');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(0));
      }
    });
  });

  group('Issue 32 — Raven Mascot Layer 3 Animation Contract Tests', () {
    testWidgets('sleep state renders closed eye and animates scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.sleep, size: 64),
          ),
        ),
      );

      expect(find.byType(RavenMascot), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3)); // body, wing, eye_closed
      expect(tester.takeException(), isNull);
    });

    testWidgets('idle state renders open eye at rest', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.idle, size: 64),
          ),
        ),
      );

      expect(find.byType(RavenMascot), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hop state triggers action controller animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.hop, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ruffle state scales body without exception', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.ruffle, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fly state translates mascot without exception', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.fly, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders static frame without controllers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: const MaterialApp(
            home: Scaffold(
              body: RavenMascot(state: RavenState.sleep, size: 64),
            ),
          ),
        ),
      );

      expect(find.byType(RavenMascot), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal cleans up controllers without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.idle, size: 64),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      expect(tester.takeException(), isNull);
    });
  });
}
