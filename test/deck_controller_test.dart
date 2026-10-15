import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/card_grid.dart';

/// Issue 198 / AM3: the deck's position now lives in a [DeckController] that a [CardGrid] and a
/// [DeckNavigationBar] can share. The vote screen's behaviour with it is tested on the whole screen in
/// `test/vote_screen_fit_test.dart`; this file pins the pieces: the controller itself, how the grid
/// opens, and how the grid and the bar follow one controller.
void main() {
  group('DeckController (Issue 198 / AM3)', () {
    test('goTo clamps to the deck, and next and previous stop at its ends', () {
      final controller = DeckController(length: 3);

      controller.goTo(99);
      expect(controller.index, 2, reason: 'past the last option');
      controller.next();
      expect(controller.index, 2, reason: 'next at the last option stays there');
      controller.goTo(-5);
      expect(controller.index, 0, reason: 'before the first option');
      controller.previous();
      expect(controller.index, 0, reason: 'previous at the first option stays there');
      controller.next();
      controller.next();
      expect(controller.index, 2);
      controller.previous();
      expect(controller.index, 1);
    });

    test('it notifies only when the index changes', () {
      final controller = DeckController(length: 3);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.previous(); // already at 0
      controller.goTo(0);
      expect(notifications, 0, reason: 'nothing moved');

      controller.next();
      expect(notifications, 1);
      controller.goTo(2);
      expect(notifications, 2);
      controller.goTo(99); // clamps to 2, where it already is
      controller.next();
      expect(notifications, 2, reason: 'clamping to the same index is not a change');
    });

    test('an empty deck stays at 0 and notifies nobody', () {
      final controller = DeckController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.next();
      controller.previous();
      controller.goTo(4);

      expect(controller.index, 0);
      expect(controller.length, 0);
      expect(notifications, 0);
    });
  });

  group('CardGrid opens where the viewer can choose (Issue 198 / AM3)', () {
    // Option I is the viewer's own forgery, which they cannot choose.
    VotingAnswer own() => VotingAnswer(authorId: 'opt1', text: 'My own forgery', isSelfAnswer: true);
    VotingAnswer other(int i) => VotingAnswer(authorId: 'opt$i', text: 'Someone else $i');

    Widget grid({
      required List<VotingAnswer> answers,
      String? selectedAuthorId,
      bool isTarget = false,
      bool openOnFirstVotable = false,
      int initialIndex = 0,
      DeckController? controller,
      bool showNavigation = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CardGrid(
              answers: answers,
              selectedAuthorId: selectedAuthorId,
              currentPlayerId: 'voter',
              isTarget: isTarget,
              initialIndex: initialIndex,
              openOnFirstVotable: openOnFirstVotable,
              controller: controller,
              showNavigation: showNavigation,
              onSelect: (_) {},
            ),
          ),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, Widget widget) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('openOnFirstVotable skips the viewer\'s own forgery', (tester) async {
      await pump(tester, grid(answers: [own(), other(2), other(3)], openOnFirstVotable: true));

      expect(find.text('CARD II OF III'), findsOneWidget);
      expect(find.text('Tap to choose this one'), findsOneWidget);
    });

    testWidgets('without openOnFirstVotable the deck opens on option I, own forgery or not, as it always did',
        (tester) async {
      await pump(tester, grid(answers: [own(), other(2), other(3)]));

      expect(find.text('CARD I OF III'), findsOneWidget);
    });

    testWidgets('a placeholder is skipped too', (tester) async {
      await pump(
        tester,
        grid(
          answers: [VotingAnswer(authorId: 'opt1', text: 'THE SOUL IS SILENT'), other(2), other(3)],
          openOnFirstVotable: true,
        ),
      );

      expect(find.text('CARD II OF III'), findsOneWidget);
    });

    // Nothing here can be chosen: a placeholder, the viewer's own forgery, and a blank.
    List<VotingAnswer> unvotable() => [
          VotingAnswer(authorId: 'opt1', text: 'THE SOUL IS SILENT'),
          own(),
          VotingAnswer(authorId: 'opt3', text: '   '),
        ];

    testWidgets('when no option can be chosen the deck falls back to initialIndex 0', (tester) async {
      await pump(tester, grid(answers: unvotable(), openOnFirstVotable: true));

      expect(find.text('CARD I OF III'), findsOneWidget);
    });

    testWidgets('when no option can be chosen the deck falls back to the initialIndex it was given', (tester) async {
      await pump(tester, grid(answers: unvotable(), openOnFirstVotable: true, initialIndex: 2));

      expect(find.text('CARD III OF III'), findsOneWidget);
    });

    testWidgets('a selection still wins', (tester) async {
      await pump(
        tester,
        grid(answers: [own(), other(2), other(3)], selectedAuthorId: 'opt3', openOnFirstVotable: true),
      );

      expect(find.text('CARD III OF III'), findsOneWidget);
    });

    testWidgets('the target opens on option I: nothing is theirs to choose', (tester) async {
      await pump(
        tester,
        grid(answers: [own(), other(2), other(3)], isTarget: true, openOnFirstVotable: true),
      );

      expect(find.text('CARD I OF III'), findsOneWidget);
    });
  });

  group('one DeckController drives a CardGrid and a DeckNavigationBar (Issue 198 / AM3)', () {
    final answers = [
      VotingAnswer(authorId: 'opt1', text: 'First answer'),
      VotingAnswer(authorId: 'opt2', text: 'Second answer'),
      VotingAnswer(authorId: 'opt3', text: 'Third answer'),
    ];

    // The deck, then the bar underneath it: the vote screen's shape, with the bar outside the deck.
    Widget deckAndBar(DeckController controller, {int? selectedIndex}) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: CardGrid(
                    answers: answers,
                    selectedAuthorId: null,
                    currentPlayerId: 'voter',
                    controller: controller,
                    showNavigation: false,
                    onSelect: (_) {},
                  ),
                ),
              ),
              DeckNavigationBar(controller: controller, selectedIndex: selectedIndex),
            ],
          ),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, Widget widget) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('with showNavigation off the deck draws no navigation row of its own', (tester) async {
      final controller = DeckController(length: 3);
      await pump(
        tester,
        MaterialApp(
          home: Scaffold(
            body: CardGrid(
              answers: answers,
              selectedAuthorId: null,
              currentPlayerId: 'voter',
              controller: controller,
              showNavigation: false,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('stacked_deck_prev_button')), findsNothing);
      expect(find.byKey(const Key('stacked_deck_next_button')), findsNothing);
      expect(find.byKey(const Key('stacked_deck_dot_0')), findsNothing);
      expect(find.text('CARD I OF III'), findsOneWidget, reason: 'the deck itself is still there');
    });

    testWidgets('the bar moves the deck, the deck\'s swipe moves the bar, and both are one controller',
        (tester) async {
      final controller = DeckController(length: 3);
      await pump(tester, deckAndBar(controller));

      expect(find.text('CARD I OF III'), findsOneWidget);
      expect(tester.widget<InkWell>(find.byKey(const Key('stacked_deck_prev_button'))).onTap, isNull);

      await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(find.text('CARD II OF III'), findsOneWidget);
      expect(tester.widget<InkWell>(find.byKey(const Key('stacked_deck_prev_button'))).onTap, isNotNull);

      await tester.tap(find.byKey(const Key('stacked_deck_dot_2')));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
      expect(find.text('CARD III OF III'), findsOneWidget);
      expect(tester.widget<InkWell>(find.byKey(const Key('stacked_deck_next_button'))).onTap, isNull);

      // A swipe on the deck unpeels one card, and the bar's enabled states follow.
      await tester.drag(find.text('Third answer'), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(find.text('CARD II OF III'), findsOneWidget);
      expect(tester.widget<InkWell>(find.byKey(const Key('stacked_deck_next_button'))).onTap, isNotNull);
    });

    testWidgets('a controller moved from outside moves the deck', (tester) async {
      final controller = DeckController(length: 3);
      await pump(tester, deckAndBar(controller));

      controller.goTo(2);
      await tester.pumpAndSettle();

      expect(find.text('CARD III OF III'), findsOneWidget);
    });

    testWidgets('the grid seeds the controller it is given with its size and where it opens', (tester) async {
      final controller = DeckController(); // length 0, index 0: the grid knows the real numbers
      await pump(
        tester,
        MaterialApp(
          home: Scaffold(
            body: CardGrid(
              answers: [VotingAnswer(authorId: 'opt1', text: 'Mine', isSelfAnswer: true), ...answers.skip(1)],
              selectedAuthorId: null,
              currentPlayerId: 'voter',
              controller: controller,
              showNavigation: false,
              openOnFirstVotable: true,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(controller.length, 3);
      expect(controller.index, 1, reason: 'the first option the viewer can choose');
    });
  });
}
