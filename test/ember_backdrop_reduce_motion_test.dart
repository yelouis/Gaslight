import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/screens/game_over_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settleDuration = Duration(milliseconds: 100);
  const settleTimeout = Duration(seconds: 5);

  group('Issue 147: EmberBackdrop Reduce Motion (Wave X1)', () {
    testWidgets('1. Falsifying test: EmberBackdrop settles under Reduce Motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: true),
            child: Scaffold(
              body: EmberBackdrop(),
            ),
          ),
        ),
      );

      // Must complete without timing out when ticker is properly guarded
      await tester.pumpAndSettle(
        settleDuration,
        EnginePhase.sendSemanticsUpdate,
        settleTimeout,
      );

      expect(find.byType(EmberBackdrop), findsOneWidget);
    });

    testWidgets('2. Over-reach guard: AnimatedBuilder present when Reduce Motion is off, absent when on', (tester) async {
      // 2a. With Reduce Motion OFF
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: false),
            child: Scaffold(
              body: EmberBackdrop(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(of: find.byType(EmberBackdrop), matching: find.byType(AnimatedBuilder)),
        findsOneWidget,
      );

      // 2b. With Reduce Motion ON
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: true),
            child: Scaffold(
              body: EmberBackdrop(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(of: find.byType(EmberBackdrop), matching: find.byType(AnimatedBuilder)),
        findsNothing,
      );
    });

    testWidgets('3. Live toggle: responds dynamically to accessibility features changes', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true, accessibleNavigation: false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmberBackdrop(),
          ),
        ),
      );
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);
      expect(
        find.descendant(of: find.byType(EmberBackdrop), matching: find.byType(AnimatedBuilder)),
        findsNothing,
      );

      // Toggle Reduce Motion OFF
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      tester.binding.handleAccessibilityFeaturesChanged();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(of: find.byType(EmberBackdrop), matching: find.byType(AnimatedBuilder)),
        findsOneWidget,
      );

      // Toggle Reduce Motion ON again
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true, accessibleNavigation: false);
      tester.binding.handleAccessibilityFeaturesChanged();
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);

      expect(
        find.descendant(of: find.byType(EmberBackdrop), matching: find.byType(AnimatedBuilder)),
        findsNothing,
      );

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    testWidgets('4. Observer is removed on dispose: does not throw setState after dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmberBackdrop(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Dispose EmberBackdrop by pumping a different widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Disposed'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Trigger accessibility features change on binding
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true, accessibleNavigation: false);
      tester.binding.handleAccessibilityFeaturesChanged();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Disposed'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
  });
}
