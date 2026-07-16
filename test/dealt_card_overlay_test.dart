import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/dealt_card_overlay.dart';
import 'package:gaslight/models/game_state.dart';

void main() {
  testWidgets('DealtCardOverlay renders under normal motion and triggers onDismiss', (WidgetTester tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DealtCardOverlay(
                phase: GamePhase.forgery,
                readerName: 'Alice',
                promptText: 'A secret prompt...',
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it renders the titles and texts
    expect(find.text('DECK OF FORGERIES'), findsOneWidget);
    expect(find.text('A secret prompt...'), findsOneWidget);

    // Tap INSPECT button
    await tester.tap(find.text('INSPECT'));
    await tester.pumpAndSettle();

    // Verify it dismissed
    expect(dismissed, isTrue);
  });

  testWidgets('DealtCardOverlay renders in reduce motion mode without exceptions', (WidgetTester tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: child!,
          );
        },
        home: Scaffold(
          body: Stack(
            children: [
              DealtCardOverlay(
                phase: GamePhase.truth,
                readerName: 'Alice',
                promptText: 'Another prompt...',
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('THE RECORD OF TRUTH'), findsOneWidget);
    expect(find.text('Another prompt...'), findsOneWidget);

    await tester.tap(find.text('DISMISS'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
