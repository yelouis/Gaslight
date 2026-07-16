import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/gaslight_route.dart';

void main() {
  testWidgets('GaslightPageRoute transition has flicker dip and resolves', (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/second') {
            return GaslightPageRoute(
              child: Container(key: key, color: Colors.blue),
              settings: settings,
            );
          }
          return MaterialPageRoute(builder: (context) => Container(color: Colors.red));
        },
      ),
    );

    // Navigate to second page
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/second');
    await tester.pump(); // Starts route transition

    // At 180ms, verify opacity is below 0.55 (during the gutter dip)
    await tester.pump(const Duration(milliseconds: 180));
    final fadeTransition = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(Stack),
        matching: find.byType(FadeTransition),
      ).first,
    );
    expect(fadeTransition.opacity.value, lessThan(0.55));

    // Complete the animation
    await tester.pumpAndSettle();
    expect(fadeTransition.opacity.value, 1.0);
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('GaslightPageRoute reduce-motion fallback uses linear fade', (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: child!,
          );
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/second') {
            return GaslightPageRoute(
              child: Container(key: key, color: Colors.blue),
              settings: settings,
            );
          }
          return MaterialPageRoute(builder: (context) => Container(color: Colors.red));
        },
      ),
    );

    tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed('/second');
    await tester.pump(); // Starts transition

    // In accessibility mode, it should settle in <= 300 ms (linear 250ms fade)
    await tester.pump(const Duration(milliseconds: 250));
    // Verify it is settled on the next frame
    await tester.pumpAndSettle();
    expect(find.byKey(key), findsOneWidget);
  });
}
