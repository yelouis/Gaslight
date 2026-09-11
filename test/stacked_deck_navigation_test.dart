import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/card_grid.dart';

void main() {
  const surface = Size(375, 812);

  final answers = [
    VotingAnswer(authorId: 'opt1', text: 'First answer for card one'),
    VotingAnswer(authorId: 'opt2', text: 'Second answer for card two'),
    VotingAnswer(authorId: 'opt3', text: 'Third answer for card three'),
    VotingAnswer(authorId: 'opt4', text: 'Fourth answer for card four'),
  ];

  Widget buildTestDeck({
    String? selectedAuthorId,
    ValueChanged<String>? onSelect,
    int initialIndex = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CardGrid(
            answers: answers,
            selectedAuthorId: selectedAuthorId,
            currentPlayerId: 'voter1',
            initialIndex: initialIndex,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('1. Button navigation: NEXT advances card, PREV unpeels to previous card', (tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestDeck());
    await tester.pumpAndSettle();

    // Initially at card 1
    expect(find.text('CARD I OF IV'), findsOneWidget);
    expect(find.text(answers[0].text), findsOneWidget);

    // PREV button is disabled at index 0
    final prevFinder = find.byKey(const Key('stacked_deck_prev_button'));
    expect(tester.widget<InkWell>(prevFinder).onTap, isNull);

    // Tap NEXT to advance to card 2
    await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('CARD II OF IV'), findsOneWidget);
    expect(find.text(answers[1].text), findsOneWidget);
    expect(tester.widget<InkWell>(prevFinder).onTap, isNotNull);

    // Tap NEXT to advance to card 3
    await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD III OF IV'), findsOneWidget);

    // Tap PREV to unpeel back to card 2
    await tester.tap(find.byKey(const Key('stacked_deck_prev_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD II OF IV'), findsOneWidget);

    // Tap PREV to unpeel back to card 1
    await tester.tap(find.byKey(const Key('stacked_deck_prev_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD I OF IV'), findsOneWidget);
  });

  testWidgets('2. Gesture swipe: horizontal swipe left peels forward, swipe right unpeels backward', (tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestDeck());
    await tester.pumpAndSettle();

    expect(find.text('CARD I OF IV'), findsOneWidget);

    // Swipe left on card container -> peels to card 2
    await tester.drag(find.text(answers[0].text), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CARD II OF IV'), findsOneWidget);

    // Swipe left again -> peels to card 3
    await tester.drag(find.text(answers[1].text), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CARD III OF IV'), findsOneWidget);

    // Swipe right -> unpeels backward to card 2!
    await tester.drag(find.text(answers[2].text), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CARD II OF IV'), findsOneWidget);

    // Swipe right again -> unpeels backward to card 1!
    await tester.drag(find.text(answers[1].text), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CARD I OF IV'), findsOneWidget);
  });

  testWidgets('3. Interactive dots: tapping any dot jumps directly to that card', (tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestDeck());
    await tester.pumpAndSettle();

    expect(find.text('CARD I OF IV'), findsOneWidget);

    // Tap dot 3 (index 3, card 4)
    await tester.tap(find.byKey(const Key('stacked_deck_dot_3')));
    await tester.pumpAndSettle();
    expect(find.text('CARD IV OF IV'), findsOneWidget);
    expect(find.text(answers[3].text), findsOneWidget);

    // NEXT button is disabled at last card
    final nextFinder = find.byKey(const Key('stacked_deck_next_button'));
    expect(tester.widget<InkWell>(nextFinder).onTap, isNull);

    // Tap dot 0 to jump back to card 1
    await tester.tap(find.byKey(const Key('stacked_deck_dot_0')));
    await tester.pumpAndSettle();
    expect(find.text('CARD I OF IV'), findsOneWidget);
  });

  testWidgets('4. Re-selection & persistence: selected card preserves wax seal across navigation and re-selection works', (tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selected;

    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardGrid(
                answers: answers,
                selectedAuthorId: selected,
                currentPlayerId: 'voter1',
                onSelect: (id) {
                  setState(() => selected = id);
                },
              ),
            ),
          ),
        );
      },
    ));
    await tester.pumpAndSettle();

    // 1. Select card 1
    await tester.tap(find.text(answers[0].text));
    await tester.pumpAndSettle();
    expect(selected, equals('opt1'));
    expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsOneWidget);

    // 2. Peel forward to card 2 and card 3
    await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD II OF IV'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD III OF IV'), findsOneWidget);

    // 3. Unpeel backward to card 1
    await tester.tap(find.byKey(const Key('stacked_deck_prev_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stacked_deck_prev_button')));
    await tester.pumpAndSettle();
    expect(find.text('CARD I OF IV'), findsOneWidget);

    // Card 1 still displays the wax seal badge!
    expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsOneWidget);

    // 4. Re-selection: Peel to card 2 and select it instead
    await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(answers[1].text));
    await tester.pumpAndSettle();

    expect(selected, equals('opt2'));
    expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsOneWidget);
  });
}
