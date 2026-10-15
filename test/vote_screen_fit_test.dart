import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 198 / AM3: the vote screen, not the deck widget, keeps the deck's navigation and the action
/// button on screen, and opens the deck on a card the voter can choose.
///
/// `test/vote_option_truncation_test.dart` (320 x 640) and `test/stacked_deck_navigation_test.dart`
/// (375 x 812) test `CardGrid` alone, and the design promise they back — six options fit in 320 x 640 with
/// no vertical scrolling — never held for the whole screen: its header, avatar, subtitles, prompt card and
/// discussion line take about 450 pt above the deck, so PREV, the dots and NEXT sat below the fold at
/// 375 x 667, and a voter's own sealed forgery was often the front card. This pumps the real `GaslightApp`
/// on the vote screen, as a voter and as the target, and measures the screen without scrolling it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the vote screen keeps its deck navigation and action button on screen (Issue 198 / AM3)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie');

    // Card A is Alice's. Bob's own forgery comes FIRST, which is what the deck used to open on.
    final cardA = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      truthAnswer: 'Alice Real Truth',
      sabotageAnswers: {'p2': 'Bob Own Forgery A', 'p3': 'Charlie Forgery A'},
      options: [
        CardAnswerOption(id: 'a1', text: 'Bob Own Forgery A'),
        CardAnswerOption(id: 'a2', text: 'Charlie Forgery A'),
        CardAnswerOption(id: 'a3', text: 'Alice Real Truth'),
      ],
    );

    // Card B is Charlie's. Bob's own forgery is first here too, so the first option he can choose is II.
    final cardB = CardModel(
      promptText: 'What is Charlie secret truth?',
      targetPlayerId: 'p3',
      truthAnswer: 'Charlie Real Truth',
      sabotageAnswers: {'p1': 'Alice Forgery B', 'p2': 'Bob Own Forgery B'},
      options: [
        CardAnswerOption(id: 'b1', text: 'Bob Own Forgery B'),
        CardAnswerOption(id: 'b2', text: 'Alice Forgery B'),
        CardAnswerOption(id: 'b3', text: 'Charlie Real Truth'),
      ],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    GameState voteState(String readerId) => GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.vote,
          totalPlayers: 3,
          currentReaderId: readerId,
          isTimerDisabled: true,
          cards: [cardA, cardB],
        );

    /// The real app (production theme and routing) on the vote screen at [size] and [textScale], with
    /// reduced motion so nothing is mid-animation when it is measured. A voter has already written their
    /// forgery for each card, so the screen knows which option is theirs.
    Future<void> pumpVoteScreen(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required String localPlayerId,
      String readerId = 'p1',
    }) async {
      final state = voteState(readerId);
      await mockDb.collection('rooms').doc('TEST').set(state.toMap());
      gameService.debugSetState(state, [p1, p2, p3], localPlayerId);
      if (localPlayerId == 'p2') {
        await gameService.submitCardAnswer('p1', 'p2', 'Bob Own Forgery A', false);
        await gameService.submitCardAnswer('p3', 'p2', 'Bob Own Forgery B', false);
      }

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const GaslightApp(),
        ),
      );
      // The lobby routes itself to the vote screen on the first frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Phase3VoteScreen), findsOneWidget, reason: 'the app did not reach the vote screen');
    }

    /// A control is on screen when, with nothing scrolled, its whole rectangle is inside the window AND inside
    /// the viewport of every scroll view it sits in (a control below a scroll view's edge can still have
    /// coordinates inside the window, and is clipped), and a tap at its centre reaches it.
    void expectOnScreen(WidgetTester tester, Finder control, String what, Size size) {
      expect(control, findsOneWidget, reason: '$what is not on the vote screen at all');
      final rect = tester.getRect(control);
      bool within(Rect outer) =>
          rect.left >= outer.left && rect.top >= outer.top && rect.right <= outer.right && rect.bottom <= outer.bottom;
      expect(
        within(Offset.zero & size),
        isTrue,
        reason: '$what is at $rect, which is not inside the ${size.width.toInt()} x ${size.height.toInt()} screen',
      );
      for (final element in find.ancestor(of: control, matching: find.byType(Scrollable)).evaluate()) {
        final box = element.renderObject! as RenderBox;
        final viewport = box.localToGlobal(Offset.zero) & box.size;
        expect(within(viewport), isTrue, reason: '$what is at $rect, which a scroll view showing only $viewport clips');
      }
      expect(control.hitTestable(), findsOneWidget, reason: '$what is covered: a tap at its centre does not reach it');
    }

    for (final size in const [Size(320, 640), Size(375, 667), Size(375, 812), Size(1280, 800)]) {
      for (final textScale in const [1.0, 1.3]) {
        final where = '${size.width.toInt()} x ${size.height.toInt()} at text scale $textScale';

        testWidgets('voter at $where: PREV, NEXT, every dot and the action button are on screen, and the deck '
            'opens on a card they can choose', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await pumpVoteScreen(tester, size: size, textScale: textScale, localPlayerId: 'p2');

            expectOnScreen(tester, find.bySemanticsLabel('Previous option'), 'Previous option', size);
            expectOnScreen(tester, find.bySemanticsLabel('Next option'), 'Next option', size);
            for (var k = 1; k <= 3; k++) {
              expectOnScreen(tester, find.bySemanticsLabel('Show option $k of 3'), 'Show option $k of 3', size);
            }
            expectOnScreen(tester, find.widgetWithText(PrimaryButton, 'TAP A CARD TO CHOOSE'), 'TAP A CARD TO CHOOSE', size);

            // Bob's own forgery is option I. The deck opens on option II, which he can choose: it shows the cue.
            expect(find.text('CARD II OF III'), findsOneWidget, reason: 'the deck did not skip the voter\'s own forgery');
            expect(find.text('Tap to choose this one'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });

        testWidgets('target at $where: PREV, NEXT, every dot and the ready button are on screen, and the deck '
            'opens on card I', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await pumpVoteScreen(tester, size: size, textScale: textScale, localPlayerId: 'p1');

            expectOnScreen(tester, find.bySemanticsLabel('Previous option'), 'Previous option', size);
            expectOnScreen(tester, find.bySemanticsLabel('Next option'), 'Next option', size);
            for (var k = 1; k <= 3; k++) {
              expectOnScreen(tester, find.bySemanticsLabel('Show option $k of 3'), 'Show option $k of 3', size);
            }
            expectOnScreen(tester, find.widgetWithText(PrimaryButton, "I'M READY"), "I'M READY", size);

            expect(find.text('CARD I OF III'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }

    testWidgets('a new card opens its own deck on its first votable option, not on the previous index', (tester) async {
      await pumpVoteScreen(tester, size: const Size(375, 667), textScale: 1.0, localPlayerId: 'p2');

      // Card A: the voter's own forgery is I, so the deck opens on II. Walk to III.
      expect(find.text('CARD II OF III'), findsOneWidget);
      await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CARD III OF III'), findsOneWidget, reason: 'the walk to option III did not happen');

      // The reader changes to Charlie: card B's room state is pumped.
      gameService.debugSetState(voteState('p3'), [p1, p2, p3], 'p2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('What is Charlie secret truth?'), findsOneWidget, reason: 'the screen did not move to card B');
      expect(find.text('CARD II OF III'), findsOneWidget,
          reason: "card B's deck must open on its first votable option (II), not on the last card's index (III) or on Bob's own forgery (I)");
      expect(find.text('Tap to choose this one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
