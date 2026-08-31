import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_motion.dart';
import 'package:gaslight/widgets/thinking_background.dart';

void main() {
  group('Issue 141: Real Reduce Motion Flag Verification (U2)', () {
    testWidgets('1. Falsifying test: AppMotion.reduce is true when reduceMotion is enabled without accessibleNavigation', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: true,
        accessibleNavigation: false,
      );

      late bool isReduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isReduced = AppMotion.reduce(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isReduced, isTrue);
    });

    testWidgets('2. Over-reach guard: accessibleNavigation: true still enables reduce motion when reduceMotion is false', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: false,
        accessibleNavigation: false,
      );

      late bool isReduced;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) {
                isReduced = AppMotion.reduce(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isReduced, isTrue);
    });

    testWidgets('3. Over-reach guard: both signals false does not reduce motion and retains particle layer', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: false,
        accessibleNavigation: false,
      );

      late bool isReduced;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: false),
            child: Builder(
              builder: (context) {
                isReduced = AppMotion.reduce(context);
                return const AnimatedThinkingBackground(child: Text('Content'));
              },
            ),
          ),
        ),
      );

      expect(isReduced, isFalse);
      final particleFinder = find.descendant(
        of: find.byType(AnimatedThinkingBackground),
        matching: find.byType(AnimatedBuilder),
      );
      expect(particleFinder, findsOneWidget);
    });

    testWidgets('4. Observer live toggle on mounted AnimatedThinkingBackground tree', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: false,
        accessibleNavigation: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThinkingBackground(child: Text('Mounted Content')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final particleFinder = find.descendant(
        of: find.byType(AnimatedThinkingBackground),
        matching: find.byType(AnimatedBuilder),
      );
      expect(particleFinder, findsOneWidget);

      // Dynamically enable reduceMotion at platform dispatcher level
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: true,
        accessibleNavigation: false,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

      expect(particleFinder, findsNothing);
    });
  });
}
